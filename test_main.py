import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from main import app
from database import get_db
from models import Base

# Test database (SQLite)
SQLALCHEMY_DATABASE_URL = "sqlite:///./test.db"

engine = create_engine(
    SQLALCHEMY_DATABASE_URL, connect_args={"check_same_thread": False}
)
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# Create tables
Base.metadata.create_all(bind=engine)


# Override DB dependency
def override_get_db():
    db = TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()


app.dependency_overrides[get_db] = override_get_db

client = TestClient(app)


def test_root():
    response = client.get("/")
    assert response.status_code == 200
    assert response.json()["status"] == "running"


def test_health():
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["database"] == "connected"


def test_create_todo():
    response = client.post(
        "/api/todos", json={"title": "Test Todo", "description": "Testing"}
    )
    assert response.status_code == 201
    assert response.json()["title"] == "Test Todo"


def test_get_todos():
    response = client.get("/api/todos")
    assert response.status_code == 200
    assert isinstance(response.json(), list)


def test_get_todo_not_found():
    response = client.get("/api/todos/9999")
    assert response.status_code == 404


def test_delete_todo():
    # create first
    create = client.post(
        "/api/todos", json={"title": "Delete Me", "description": "temp"}
    )
    todo_id = create.json()["id"]

    delete = client.delete(f"/api/todos/{todo_id}")
    assert delete.status_code == 200
