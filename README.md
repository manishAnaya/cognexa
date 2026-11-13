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

### Document processing on Render Free

Document uploads create a pending PostgreSQL job and return before indexing. A single worker thread starts with the FastAPI lifespan, claims jobs with PostgreSQL row locks, and uses leases and bounded retries to recover interrupted work. The thread stops during application shutdown; if an active job does not finish before shutdown, its lease expires and a later worker can reclaim it.

This is a best-effort Render Free arrangement, not continuous background execution. Render Free web services can spin down while idle, so queued jobs wait until the service starts again. Job rows persist in PostgreSQL, but this phase still uses local `uploads/` and `chroma_db/` paths; those files and vectors can disappear on restart or spin-down. A pending job whose source upload is gone cannot be recovered until durable document and vector storage are added in a later phase.

## Project layout

```text
app/          FastAPI API, database models, ingestion, retrieval, and RAG
migrations/   Alembic database migrations
frontend/     Flutter application
uploads/      Local uploaded files (ignored by Git)
chroma_db/    Local vector data (ignored by Git)
```

`project_documentation.txt`, `blueprint.txt`, and `blueprints.md` contain product and design planning material. This README describes the current implementation and local setup.
