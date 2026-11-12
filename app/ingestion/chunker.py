import re
from langchain_text_splitters import RecursiveCharacterTextSplitter
from langchain_core.documents import Document

def clean_text(text: str) -> str:
    text = text.replace("\x00", "")
    text = re.sub(r"[\t]+", " ", text)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip()

def split_documents(pages: list[dict]) -> list[dict]:
    documents = []
    # Convert extracted page dictionaries into LangChain Documents
    for page_data in pages:
        text = clean_text(page_data["text"])
        if not text:
            continue
        documents.append(Document(
            page_content=text, metadata={"page": page_data["page"]}
        ))
    splitter = RecursiveCharacterTextSplitter(
        chunk_size=1000,
        chunk_overlap=200,
        separators=["\n\n", "\n", ". ", " ", ""]
    )
    chunks = splitter.split_documents(documents)
     # Add a unique sequential chunk index
    for index, chunk in enumerate(chunks):
        chunk.metadata["chunk_index"] = index
    return chunks