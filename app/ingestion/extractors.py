import csv
from pathlib import Path
from pypdf import PdfReader
from docx import Document as DocxDocument

def extract_pdf(file_path: str) -> list[dict]:
    reader = PdfReader(file_path)
    return [
        {
            "text": page.extract_text() or "",
            "page": index + 1
        }
        for index, page in enumerate(reader.pages)
    ]


def extract_docx(file_path: str) -> list[dict]:
    doc = DocxDocument(file_path)
    text = "\n".join(
        paragraph.text
        for paragraph in doc.paragraphs
        if paragraph.text.strip()
    )
    return [{"text": text, "page": None}]

def extract_txt(file_path: str) -> list[dict]:
    text = Path(file_path).read_text(encoding="utf-8-sig")
    return [{"text": text, "page": None}]

def extract_markdown(file_path: str) -> list[dict]:
    text = Path(file_path).read_text(encoding="utf-8-sig")
    return [{"text": text, "page": None}]

def extract_csv(file_path: str) -> list[dict]:
    rows = []
    with open(file_path, "r", encoding="utf-8-sig", newline="") as file:
        reader = csv.reader(file)
        for row in reader:
            rows.append(" | ".join(row))
    text = "\n".join(rows)
    return [{"text": text, "page": None}]


def extract_document(file_path: str) -> list[dict]:
    extension = Path(file_path).suffix.lower()
    
    extractors = {
        ".pdf": extract_pdf,
        ".docx": extract_docx,
        ".txt": extract_txt,
        ".md": extract_markdown,
        ".csv": extract_csv
    }

    extractor = extractors.get(extension)
    if not extractor:
        raise ValueError("Unsupported document format")
    return extractor(file_path)