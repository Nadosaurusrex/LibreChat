# app/utils/document_loader.py
# Patched: uses PyMuPDF (fitz) for PDF extraction instead of pypdf

import os
import re
import codecs
import tempfile

from typing import List, Optional
import chardet

from langchain_core.documents import Document

from app.config import known_source_ext, PDF_EXTRACT_IMAGES, CHUNK_OVERLAP, logger
from langchain_community.document_loaders import (
    TextLoader,
    CSVLoader,
    Docx2txtLoader,
    UnstructuredEPubLoader,
    UnstructuredMarkdownLoader,
    UnstructuredXMLLoader,
    UnstructuredRSTLoader,
    UnstructuredExcelLoader,
    UnstructuredPowerPointLoader,
)


def detect_file_encoding(filepath: str) -> str:
    """
    Detect the encoding of a file using BOM markers and chardet for broader support.
    Returns the detected encoding or 'utf-8' as default.
    """
    with open(filepath, "rb") as f:
        raw = f.read(4096)  # Read a larger sample for better detection

    # Check for BOM markers first
    if raw.startswith(codecs.BOM_UTF16_LE):
        return "utf-16-le"
    elif raw.startswith(codecs.BOM_UTF16_BE):
        return "utf-16-be"
    elif raw.startswith(codecs.BOM_UTF16):
        return "utf-16"
    elif raw.startswith(codecs.BOM_UTF8):
        return "utf-8-sig"
    elif raw.startswith(codecs.BOM_UTF32_LE):
        return "utf-32-le"
    elif raw.startswith(codecs.BOM_UTF32_BE):
        return "utf-32-be"

    # Use chardet to detect encoding if no BOM is found
    result = chardet.detect(raw)
    encoding = result.get("encoding")
    if encoding:
        return encoding.lower()
    # Default to utf-8 if detection fails
    return "utf-8"


def cleanup_temp_encoding_file(loader) -> None:
    """
    Clean up temporary UTF-8 file if it was created for encoding conversion.

    :param loader: The document loader that may have created a temporary file
    """
    if hasattr(loader, "_temp_filepath") and loader._temp_filepath is not None:
        try:
            os.remove(loader._temp_filepath)
        except Exception as e:
            logger.warning(f"Failed to remove temporary UTF-8 file: {e}")


class PyMuPDFLoader:
    """PDF loader using PyMuPDF (fitz) for better text extraction quality."""

    def __init__(self, filepath: str, extract_images: bool = False):
        self.filepath = filepath
        self.extract_images = extract_images
        self._temp_filepath = None

    def load(self) -> List[Document]:
        import fitz
        doc = fitz.open(self.filepath)
        documents = []
        for i, page in enumerate(doc):
            text = page.get_text()
            text = fix_spaced_headings(text)
            text = clean_text(text)
            if text.strip():
                documents.append(Document(
                    page_content=text,
                    metadata={"source": self.filepath, "page": i}
                ))
        doc.close()
        return documents


def fix_spaced_headings(text):
    """Fix headings where characters are spaced out like 'E V E N T I'."""
    lines = []
    for line in text.split('\n'):
        words = line.split()
        if len(words) > 3 and sum(1 for w in words if len(w) == 1) / len(words) > 0.5:
            collapsed = re.sub(r'(\S) (?=\S)', r'\1', line)
            collapsed = re.sub(r'([.!?;:])([A-ZÀ-Ú])', r'\1 \2', collapsed)
            collapsed = re.sub(r'([a-zà-ú])([A-ZÀ-Ú])', r'\1 \2', collapsed)
            collapsed = re.sub(r'([a-zA-Zà-úÀ-Ú])(\d)', r'\1 \2', collapsed)
            collapsed = re.sub(r'(\d)([a-zA-Zà-úÀ-Ú])', r'\1 \2', collapsed)
            collapsed = re.sub(r',([a-zA-Zà-úÀ-Ú])', r', \1', collapsed)
            collapsed = re.sub(r' +', ' ', collapsed)
            lines.append(collapsed.strip())
        else:
            lines.append(line)
    return '\n'.join(lines)


def get_loader(filename: str, file_content_type: str, filepath: str):
    """Get the appropriate document loader based on file type and/or content type."""
    file_ext = filename.split(".")[-1].lower()
    known_type = True

    if file_ext == "pdf" or file_content_type == "application/pdf":
        loader = PyMuPDFLoader(filepath, extract_images=PDF_EXTRACT_IMAGES)
    elif file_ext == "csv" or file_content_type == "text/csv":
        encoding = detect_file_encoding(filepath)

        if encoding != "utf-8":
            temp_file = None
            try:
                with tempfile.NamedTemporaryFile(
                    mode="w", encoding="utf-8", suffix=".csv", delete=False
                ) as temp_file:
                    with open(
                        filepath, "r", encoding=encoding, errors="replace"
                    ) as original_file:
                        content = original_file.read()
                        temp_file.write(content)

                    temp_filepath = temp_file.name

                loader = CSVLoader(temp_filepath)
                loader._temp_filepath = temp_filepath
            except Exception as e:
                if temp_file and os.path.exists(temp_file.name):
                    os.unlink(temp_file.name)
                raise e
        else:
            loader = CSVLoader(filepath)
    elif file_ext == "rst":
        loader = UnstructuredRSTLoader(filepath, mode="elements")
    elif file_ext == "xml" or file_content_type in [
        "application/xml",
        "text/xml",
        "application/xhtml+xml",
    ]:
        loader = UnstructuredXMLLoader(filepath)
    elif file_ext in ["ppt", "pptx"] or file_content_type in [
        "application/vnd.ms-powerpoint",
        "application/vnd.openxmlformats-officedocument.presentationml.presentation",
    ]:
        loader = UnstructuredPowerPointLoader(filepath)
    elif file_ext == "md" or file_content_type in [
        "text/markdown",
        "text/x-markdown",
        "application/markdown",
        "application/x-markdown",
    ]:
        loader = UnstructuredMarkdownLoader(filepath)
    elif file_ext == "epub" or file_content_type == "application/epub+zip":
        loader = UnstructuredEPubLoader(filepath)
    elif file_ext in ["doc", "docx"] or file_content_type in [
        "application/msword",
        "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
    ]:
        loader = Docx2txtLoader(filepath)
    elif file_ext in ["xls", "xlsx"] or file_content_type in [
        "application/vnd.ms-excel",
        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    ]:
        loader = UnstructuredExcelLoader(filepath)
    elif file_ext == "json" or file_content_type == "application/json":
        loader = TextLoader(filepath, autodetect_encoding=True)
    elif file_ext in known_source_ext or (
        file_content_type and file_content_type.find("text/") >= 0
    ):
        loader = TextLoader(filepath, autodetect_encoding=True)
    else:
        loader = TextLoader(filepath, autodetect_encoding=True)
        known_type = False

    return loader, known_type, file_ext


def clean_text(text: str) -> str:
    """Clean up text from PDF loader."""
    text = remove_null(text)
    text = remove_non_utf8(text)
    return text


def remove_null(text: str) -> str:
    """Remove NUL (0x00) characters from a string."""
    return text.replace("\x00", "")


def remove_non_utf8(text: str) -> str:
    """Remove invalid UTF-8 characters from a string."""
    try:
        return text.encode("utf-8", "ignore").decode("utf-8")
    except UnicodeError:
        return text


def process_documents(documents: List[Document]) -> str:
    processed_text = ""
    last_page: Optional[int] = None
    doc_basename = ""

    for doc in documents:
        if "source" in doc.metadata:
            doc_basename = doc.metadata["source"].split("/")[-1]
            break

    processed_text += f"{doc_basename}\n"

    for doc in documents:
        current_page = doc.metadata.get("page")
        if current_page and current_page != last_page:
            processed_text += f"\n# PAGE {doc.metadata['page']}\n\n"
            last_page = current_page

        new_content = doc.page_content
        if processed_text.endswith(new_content[:CHUNK_OVERLAP]):
            processed_text += new_content[CHUNK_OVERLAP:]
        else:
            processed_text += new_content

    return processed_text.strip()
