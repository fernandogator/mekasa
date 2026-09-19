"""Firestore-backed household members + invites (REQ-019)."""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Any
from uuid import uuid4

from google.cloud import firestore

from app.config import Settings
from app.models import (
    HouseholdInviteCreateRequest,
    HouseholdInviteResponse,
    HouseholdMemberResponse,
    HouseholdMemberRoleUpdateRequest,
)
from app.repository import get_household_repository

HOUSEHOLDS = "households"
MEMBERS = "members"
INVITES = "invites"
INVITE_TOKENS = "invite_tokens"
USER_MEMBERSHIPS = "user_memberships"


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


def _member_from(household_id: str, uid: str, data: dict[str, Any]) -> HouseholdMemberResponse:
    raw_perms = data.get("permissions") or []
    permissions = [str(p) for p in raw_perms] if isinstance(raw_perms, list) else []
    return HouseholdMemberResponse(
        uid=uid,
        household_id=household_id,
        name=data.get("name"),
        email=data.get("email"),
        phone=data.get("phone"),
        role=data.get("role") or "member",
        status=data.get("status") or "active",
        permissions=permissions,
        created_at=data["created_at"],
        updated_at=data["updated_at"],
    )


def _invite_from(household_id: str, invite_id: str, data: dict[str, Any]) -> HouseholdInviteResponse:
    return HouseholdInviteResponse(
        id=invite_id,
        household_id=household_id,
        name=str(data["name"]),
        email=data.get("email"),
        phone=data.get("phone"),
        role=data.get("role") or "member",
        token=str(data["token"]),
        status=data.get("status") or "pending",
        invited_by_uid=str(data["invited_by_uid"]),
        created_at=data["created_at"],
        updated_at=data["updated_at"],
        invite_link=data.get("invite_link"),
    )


class FirestoreMembersRepository:
    """
    Satisfies: REQ-019
    Spec version: 1.0

    Paths:
      households/{id}/members/{uid}
      households/{id}/invites/{invite_id}
      invite_tokens/{token} → {household_id, invite_id}
      user_memberships/{uid}/households/{household_id}
    """

    def __init__(self, client: firestore.Client) -> None:
        self._db = client

    @classmethod
    def from_settings(cls, settings: Settings) -> FirestoreMembersRepository:
        client = firestore.Client(
            project=settings.gcp_project_id or settings.firebase_project_id,
            database=settings.firestore_database_id,
        )
        return cls(client)

    def _members_col(self, household_id: str):
        return self._db.collection(HOUSEHOLDS).document(household_id).collection(MEMBERS)

    def _invites_col(self, household_id: str):
        return self._db.collection(HOUSEHOLDS).document(household_id).collection(INVITES)

    def _ensure_owner_member(
        self, household_id: str, owner_uid: str, owner_name: str | None
    ) -> None:
        ref = self._members_col(household_id).document(owner_uid)
        if ref.get().exists:
            return
        now = _utcnow()
        data = {
            "name": owner_name,
            "email": None,
            "phone": None,
            "role": "owner",
            "status": "active",
            "created_at": now,
            "updated_at": now,
        }
        ref.set(data)
        self._db.collection(USER_MEMBERSHIPS).document(owner_uid).collection(HOUSEHOLDS).document(
            household_id
        ).set({"role": "owner", "status": "active", "updated_at": now})

    def _require_owner(self, household_id: str, actor_uid: str) -> None:
        households = get_household_repository()
        household = households.get(household_id)
        if household is None:
            raise KeyError(household_id)
        self._ensure_owner_member(household_id, household.owner_uid, household.name)
        if household.owner_uid == actor_uid:
            return
        snap = self._members_col(household_id).document(actor_uid).get()
        if not snap.exists:
            raise PermissionError(household_id)
        data = snap.to_dict() or {}
        if data.get("role") != "owner" or data.get("status") != "active":
            raise PermissionError(household_id)

    def _require_member_or_owner(self, household_id: str, actor_uid: str) -> None:
        households = get_household_repository()
        household = households.get(household_id)
        if household is None:
            raise KeyError(household_id)
        self._ensure_owner_member(household_id, household.owner_uid, household.name)
        if household.owner_uid == actor_uid:
            return
        if not self.is_active_participant(household_id, actor_uid):
            raise PermissionError(household_id)

    def list_members(self, household_id: str, actor_uid: str) -> list[HouseholdMemberResponse]:
        self._require_member_or_owner(household_id, actor_uid)
        members = [
            _member_from(household_id, snap.id, dict(snap.to_dict() or {}))
            for snap in self._members_col(household_id).stream()
        ]
        return sorted(
            members,
            key=lambda item: (0 if item.role == "owner" else 1, item.name or item.uid),
        )

    def create_invite(
        self, household_id: str, actor_uid: str, payload: HouseholdInviteCreateRequest
    ) -> HouseholdInviteResponse:
        self._require_owner(household_id, actor_uid)
        if not payload.email and not payload.phone:
            raise ValueError("email_or_phone_required")
        now = _utcnow()
        invite_id = str(uuid4())
        token = uuid4().hex
        data = {
            "name": payload.name.strip(),
            "email": payload.email,
            "phone": payload.phone,
            "role": payload.role,
            "token": token,
            "status": "pending",
            "invited_by_uid": actor_uid,
            "created_at": now,
            "updated_at": now,
            "invite_link": f"https://mekasa.app/invite/{token}",
        }
        batch = self._db.batch()
        batch.set(self._invites_col(household_id).document(invite_id), data)
        batch.set(
            self._db.collection(INVITE_TOKENS).document(token),
            {"household_id": household_id, "invite_id": invite_id},
        )
        batch.commit()
        return _invite_from(household_id, invite_id, data)

    def list_invites(self, household_id: str, actor_uid: str) -> list[HouseholdInviteResponse]:
        self._require_owner(household_id, actor_uid)
        invites = [
            _invite_from(household_id, snap.id, dict(snap.to_dict() or {}))
            for snap in self._invites_col(household_id).stream()
        ]
        return sorted(invites, key=lambda item: item.created_at, reverse=True)

    def accept_invite(
        self, token: str, actor_uid: str, actor_name: str | None
    ) -> HouseholdMemberResponse:
        token_ref = self._db.collection(INVITE_TOKENS).document(token)
        token_snap = token_ref.get()
        if not token_snap.exists:
            raise KeyError(token)
        token_data = token_snap.to_dict() or {}
        household_id = str(token_data["household_id"])
        invite_id = str(token_data["invite_id"])
        invite_ref = self._invites_col(household_id).document(invite_id)
        invite_snap = invite_ref.get()
        if not invite_snap.exists:
            raise KeyError(token)
        invite = dict(invite_snap.to_dict() or {})
        if invite.get("status") != "pending":
            raise ValueError("invite_not_pending")
        now = _utcnow()
        member_data = {
            "name": actor_name or invite.get("name"),
            "email": invite.get("email"),
            "phone": invite.get("phone"),
            "role": invite.get("role") or "member",
            "status": "active",
            "created_at": now,
            "updated_at": now,
        }
        batch = self._db.batch()
        batch.set(self._members_col(household_id).document(actor_uid), member_data)
        batch.update(invite_ref, {"status": "accepted", "updated_at": now})
        batch.set(
            self._db.collection(USER_MEMBERSHIPS)
            .document(actor_uid)
            .collection(HOUSEHOLDS)
            .document(household_id),
            {
                "role": member_data["role"],
                "status": "active",
                "updated_at": now,
            },
        )
        batch.commit()
        return _member_from(household_id, actor_uid, member_data)

    def update_role(
        self,
        household_id: str,
        member_uid: str,
        actor_uid: str,
        payload: HouseholdMemberRoleUpdateRequest,
    ) -> HouseholdMemberResponse:
        self._require_owner(household_id, actor_uid)
        ref = self._members_col(household_id).document(member_uid)
        snap = ref.get()
        if not snap.exists:
            raise KeyError(member_uid)
        data = dict(snap.to_dict() or {})
        if member_uid == actor_uid and payload.role != "owner":
            raise ValueError("cannot_demote_self")
        updates = {"role": payload.role, "updated_at": _utcnow()}
        data.update(updates)
        batch = self._db.batch()
        batch.update(ref, updates)
        batch.set(
            self._db.collection(USER_MEMBERSHIPS)
            .document(member_uid)
            .collection(HOUSEHOLDS)
            .document(household_id),
            {
                "role": payload.role,
                "status": data.get("status") or "active",
                "updated_at": updates["updated_at"],
            },
            merge=True,
        )
        batch.commit()
        return _member_from(household_id, member_uid, data)

    def is_active_participant(self, household_id: str, actor_uid: str) -> bool:
        snap = self._members_col(household_id).document(actor_uid).get()
        if not snap.exists:
            return False
        return (snap.to_dict() or {}).get("status") == "active"

    def has_role(self, household_id: str, actor_uid: str, *, role: str) -> bool:
        snap = self._members_col(household_id).document(actor_uid).get()
        if not snap.exists:
            return False
        data = snap.to_dict() or {}
        return data.get("status") == "active" and data.get("role") == role

    def has_permission(self, household_id: str, actor_uid: str, permission: str) -> bool:
        snap = self._members_col(household_id).document(actor_uid).get()
        if not snap.exists:
            return False
        data = snap.to_dict() or {}
        if data.get("status") != "active":
            return False
        perms = data.get("permissions") or []
        return isinstance(perms, list) and permission in perms

    def primary_household_id_for_user(self, actor_uid: str) -> str | None:
        snaps = list(
            self._db.collection(USER_MEMBERSHIPS)
            .document(actor_uid)
            .collection(HOUSEHOLDS)
            .stream()
        )
        for snap in snaps:
            data = snap.to_dict() or {}
            if data.get("status") == "active":
                return snap.id
        return None
