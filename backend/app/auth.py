"""Firebase Auth bearer-token verification."""

from dataclasses import dataclass

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from app.config import Settings, get_settings
from app.firebase_app import ensure_firebase_app

_bearer = HTTPBearer(auto_error=False)


@dataclass(frozen=True)
class AuthUser:
    """Authenticated caller."""

    uid: str
    email: str | None = None
    name: str | None = None


def verify_bearer_token(
    credentials: HTTPAuthorizationCredentials | None = Depends(_bearer),
    settings: Settings = Depends(get_settings),
) -> AuthUser:
    """
    Satisfies: REQ-001, NFR-002, REQ-022
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

    project_id = settings.firebase_project_id or settings.gcp_project_id
    if not project_id and not settings.google_application_credentials:
        # A bearer was presented but this environment cannot verify it.
        # Return 401 so clients treat it as an expired/invalid session (REQ-022).
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired Firebase ID token",
        )

    try:
        ensure_firebase_app(settings)
        from firebase_admin import auth as firebase_auth

        decoded = firebase_auth.verify_id_token(token)
    except HTTPException:
        raise
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
