# Cognexa

Cognexa is a document research app with a Flutter frontend and a FastAPI backend. Users can create accounts and workspaces, upload PDF/DOCX/TXT/CSV/Markdown files, and ask questions about indexed workspace documents.

## Stack

- Flutter, Riverpod, and Dio
- FastAPI, SQLAlchemy, and PostgreSQL
- LangGraph for the retrieval and answer workflow
- PostgreSQL for app data and graph checkpoints
- Chroma plus BM25 for retrieval, with a cross-encoder reranker
- Groq for query rewriting, evidence validation, and answer generation
- Hugging Face sentence-transformers for embeddings

## Run locally (Windows PowerShell)

### 1. Start PostgreSQL

Create a PostgreSQL database named `cognexa`, then configure its connection string in `.env`.

### 2. Configure and start the API

From the repository root:

```powershell
Copy-Item .env.example .env
```

Edit `.env` and set `DATABASE_URL`, a private `JWT_SECRET_KEY`, and `GROQ_API_KEY`. The RAG chat needs a Groq API key. The embedding and reranker models download on first use.

Then run:

```powershell
uv sync
uv run alembic upgrade head
uv run uvicorn app.main:app --reload
```

The API is available at `http://127.0.0.1:8000`; interactive API docs are at `http://127.0.0.1:8000/docs`.

### 3. Start the Flutter app

In another terminal:

```powershell
Set-Location frontend
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1
```

The backend permits localhost origins for development. For deployment, set `CORS_ALLOWED_ORIGINS` to a comma-separated list of frontend origins and use HTTPS.

## Project layout

```text
app/          FastAPI API, database models, ingestion, retrieval, and RAG
migrations/   Alembic database migrations
frontend/     Flutter application
uploads/      Local uploaded files (ignored by Git)
chroma_db/    Local vector data (ignored by Git)
```

`project_documentation.txt`, `blueprint.txt`, and `blueprints.md` contain product and design planning material. This README describes the current implementation and local setup.
