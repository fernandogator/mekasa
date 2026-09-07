"""Shared Firebase Admin initialization."""

from __future__ import annotations

import firebase_admin
from firebase_admin import credentials

from app.config import Settings

_initialized = False


def ensure_firebase_app(settings: Settings) -> firebase_admin.App:
    """
    Initialize firebase-admin once for Auth and related services.

    Satisfies: REQ-001, NFR-004
    Acceptance criteria: AC1–AC3 (credentials via ADC / Secret Manager path)
    Spec version: 1.0
    """
    global _initialized
    if firebase_admin._apps:
        _initialized = True
        return firebase_admin.get_app()

    project_id = settings.firebase_project_id or settings.gcp_project_id
    options = {"projectId": project_id} if project_id else None

    if settings.google_application_credentials:
        cred = credentials.Certificate(settings.google_application_credentials)
        app = firebase_admin.initialize_app(cred, options)
    else:
        # Cloud Run / gcloud Application Default Credentials
        app = firebase_admin.initialize_app(options=options)

    _initialized = True
    return app


def reset_firebase_app_for_tests() -> None:
    """Clear firebase apps between tests when needed."""
    global _initialized
    for app in list(firebase_admin._apps.values()):
        firebase_admin.delete_app(app)
    _initialized = False
