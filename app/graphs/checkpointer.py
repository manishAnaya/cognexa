from psycopg_pool import ConnectionPool
from langgraph.checkpoint.postgres import PostgresSaver
from app.core.config import settings

# Connection pool shared by LangGraph checkpoint operations.
connection_kwargs = {"autocommit": True, "prepare_threshold": 0,}

pool = ConnectionPool(
    conninfo=settings.DATABASE_URL.replace(
        "postgresql+psycopg://",
        "postgresql://",
        1,
    ),
    kwargs=connection_kwargs,
    min_size=1,
    max_size=5,
    open=False,
)

checkpointer = PostgresSaver(pool)

def setup_checkpointer():
    """Create LangGraph checkpoint tables if they don't exist."""
    pool.open(wait=True)
    checkpointer.setup()
