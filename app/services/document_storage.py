import uuid
from pathlib import Path

UPLOAD_DIR = Path("uploads")
MAX_FILE_SIZE = 20 * 1024 * 1024  # 20 MB

ALLOWED_EXTENSIONS = {".pdf", ".docx", ".txt", ".csv", ".md"}

def save_document(filename: str, content: bytes, workspace_id: uuid.UUID):
    extension = Path(filename).suffix.lower()

    if extension not in ALLOWED_EXTENSIONS:
        raise ValueError("Unsupported file format")

    if len(content) > MAX_FILE_SIZE:
        raise ValueError("File size exceeds 20 MB")

    file_id = uuid.uuid4()

    directory = UPLOAD_DIR / str(workspace_id)
    directory.mkdir(parents=True, exist_ok=True)

    file_path = directory / f"{file_id}{extension}"
    file_path.write_bytes(content)

    return file_path, extension


def delete_document_file(file_path: str):
    path = Path(file_path)
    if path.exists():
        path.unlink()