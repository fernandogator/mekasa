"""FCM send helpers — no-op when Admin Messaging is unavailable."""

from __future__ import annotations

import logging
from typing import Any

logger = logging.getLogger(__name__)


def send_push_to_tokens(
    tokens: list[str],
    *,
    title: str,
    body: str,
    data: dict[str, str] | None = None,
) -> dict[str, Any]:
    """
    Attempt FCM multicast. Returns a status dict; never raises for missing creds.

    Satisfies: PRD §8 scaffold (invite / activity pushes)
    Spec version: 1.0
    """
    unique = [t for t in dict.fromkeys(tokens) if t]
    if not unique:
        return {"sent": 0, "skipped": "no_tokens"}

    try:
        from firebase_admin import messaging
    except Exception as exc:  # pragma: no cover - import guard
        logger.info("FCM unavailable: %s", exc)
        return {"sent": 0, "skipped": "firebase_admin_messaging_unavailable"}

    message = messaging.MulticastMessage(
        notification=messaging.Notification(title=title, body=body),
        data=data or {},
        tokens=unique,
    )
    try:
        response = messaging.send_each_for_multicast(message)
        return {
            "sent": response.success_count,
            "failure_count": response.failure_count,
            "skipped": None,
        }
    except Exception as exc:
        # Common in local/test without credentials / APNs key.
        logger.info("FCM send skipped: %s", exc)
        return {"sent": 0, "skipped": str(exc)}


def notify_invite_created(
    *,
    owner_tokens: list[str],
    invitee_name: str,
    invite_link: str | None,
) -> dict[str, Any]:
    """Notify household owners that an invite was created (delivery audit)."""
    deep = invite_link or ""
    return send_push_to_tokens(
        owner_tokens,
        title="Invite sent",
        body=f"Invitation for {invitee_name} is ready to share.",
        data={"deep_link": deep, "kind": "invite_created"},
    )


def notify_invite_accepted(
    *,
    owner_tokens: list[str],
    member_name: str,
) -> dict[str, Any]:
    """Notify owners when someone joins via invite."""
    return send_push_to_tokens(
        owner_tokens,
        title="New household member",
        body=f"{member_name} joined your household.",
        data={"kind": "invite_accepted"},
    )
