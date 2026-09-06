"""Firebase Auth bearer-token verification."""

from dataclasses import dataclass

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from app.config import Settings, get_settings

_bearer = HTTPBearer(auto_error=False)
_firebase_ready = False


@dataclass(frozen=True)
class AuthUser:
    """Authenticated caller."""

    uid: str
    email: str | None = None
    name: str | None = None


def _ensure_firebase(settings: Settings) -> None:
    """Initialize firebase-admin once."""
    global _firebase_ready
    if _firebase_ready:
        return
    try:
        import firebase_admin
        from firebase_admin import credentials
    except ImportError as exc:  # pragma: no cover
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="firebase-admin is not installed",
        ) from exc

    if firebase_admin._apps:
        _firebase_ready = True
        return

    project_id = settings.firebase_project_id or settings.gcp_project_id
    if not project_id and not settings.google_application_credentials:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=(
                "Firebase is not configured. Set FIREBASE_PROJECT_ID / "
                "GCP_PROJECT_ID and credentials, or set ALLOW_TEST_AUTH=true."
            ),
        )

    if settings.google_application_credentials:
        cred = credentials.Certificate(settings.google_application_credentials)
        firebase_admin.initialize_app(
            cred, {"projectId": project_id} if project_id else None
        )
    else:
        firebase_admin.initialize_app(
            options={"projectId": project_id} if project_id else None
        )
    _firebase_ready = True


def verify_bearer_token(
    credentials: HTTPAuthorizationCredentials | None = Depends(_bearer),
    settings: Settings = Depends(get_settings),
) -> AuthUser:
    """
    Satisfies: REQ-001, NFR-002
    Acceptance criteria: AC1, AC2, AC3
    Spec version: 1.0

    Verifies a Firebase ID token. With ALLOW_TEST_AUTH=true, accepts
    ``Authorization: Bearer test:<uid>``.
    """
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing bearer token",
        )

    token = credentials.credentials
    if settings.allow_test_auth and token.startswith("test:"):
        uid = token.removeprefix("test:").strip() or "test-user"
        return AuthUser(uid=uid, email=f"{uid}@example.com", name="Test User")

    _ensure_firebase(settings)
    try:
        from firebase_admin import auth as firebase_auth

        decoded = firebase_auth.verify_id_token(token)
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired Firebase ID token",
        ) from exc

    return AuthUser(
        uid=str(decoded["uid"]),
        email=decoded.get("email"),
        name=decoded.get("name"),
    )
