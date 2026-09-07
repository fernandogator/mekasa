"""Unit tests for persistence mode selection."""

from app.config import Settings
from app.repository import resolve_persistence_mode


def test_auto_uses_firestore_in_prod() -> None:
    settings = Settings(
        environment="prod",
        household_persistence="auto",
        gcp_project_id="hackathon2025-472017",
    )
    assert resolve_persistence_mode(settings) == "firestore"


def test_auto_uses_memory_locally() -> None:
    settings = Settings(environment="local", household_persistence="auto")
    assert resolve_persistence_mode(settings) == "memory"


def test_explicit_firestore() -> None:
    settings = Settings(environment="local", household_persistence="firestore")
    assert resolve_persistence_mode(settings) == "firestore"
