"""Household members + invites (REQ-019)."""

from __future__ import annotations

from datetime import datetime, timezone
from threading import Lock
from typing import Protocol
from uuid import uuid4

from app.models import (
    HouseholdInviteCreateRequest,
    HouseholdInviteResponse,
    HouseholdMemberResponse,
    HouseholdMemberRoleUpdateRequest,
)
from app.repository import get_household_repository


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


class MembersRepository(Protocol):
    """Persistence port for household members and invites."""

    def list_members(self, household_id: str, actor_uid: str) -> list[HouseholdMemberResponse]:
        """List members visible to an active household participant."""

    def create_invite(
        self, household_id: str, actor_uid: str, payload: HouseholdInviteCreateRequest
    ) -> HouseholdInviteResponse:
        """Create a pending invite (owner only)."""

    def list_invites(self, household_id: str, actor_uid: str) -> list[HouseholdInviteResponse]:
        """List invites (owner only)."""

    def accept_invite(
        self, token: str, actor_uid: str, actor_name: str | None
    ) -> HouseholdMemberResponse:
        """Accept invite and join household as member."""

    def update_role(
        self,
        household_id: str,
        member_uid: str,
        actor_uid: str,
        payload: HouseholdMemberRoleUpdateRequest,
    ) -> HouseholdMemberResponse:
        """Owner updates another member's role."""


class InMemoryMembersRepository:
    """
    Satisfies: REQ-019
    Spec version: 1.0
    """

    def __init__(self) -> None:
        self._members: dict[str, dict[str, HouseholdMemberResponse]] = {}
        self._invites: dict[str, HouseholdInviteResponse] = {}
        self._lock = Lock()

    def _ensure_owner_member(
        self, household_id: str, owner_uid: str, owner_name: str | None
    ) -> None:
        bucket = self._members.setdefault(household_id, {})
        if owner_uid in bucket:
            return
        now = _utcnow()
        bucket[owner_uid] = HouseholdMemberResponse(
            uid=owner_uid,
            household_id=household_id,
            name=owner_name,
            email=None,
            phone=None,
            role="owner",
            status="active",
            created_at=now,
            updated_at=now,
        )

    def _require_owner(self, household_id: str, actor_uid: str) -> None:
        households = get_household_repository()
        household = households.get(household_id)
        if household is None:
            raise KeyError(household_id)
        if household.owner_uid != actor_uid:
            member = self._members.get(household_id, {}).get(actor_uid)
            if member is None or member.role != "owner" or member.status != "active":
                raise PermissionError(household_id)
        self._ensure_owner_member(household_id, household.owner_uid, household.name)

    def _require_member_or_owner(self, household_id: str, actor_uid: str) -> None:
        households = get_household_repository()
        household = households.get(household_id)
        if household is None:
            raise KeyError(household_id)
        self._ensure_owner_member(household_id, household.owner_uid, household.name)
        if household.owner_uid == actor_uid:
            return
        member = self._members.get(household_id, {}).get(actor_uid)
        if member is None or member.status != "active":
            raise PermissionError(household_id)

    def list_members(self, household_id: str, actor_uid: str) -> list[HouseholdMemberResponse]:
        self._require_member_or_owner(household_id, actor_uid)
        return sorted(
            self._members.get(household_id, {}).values(),
            key=lambda item: (0 if item.role == "owner" else 1, item.name or item.uid),
        )

    def create_invite(
        self, household_id: str, actor_uid: str, payload: HouseholdInviteCreateRequest
    ) -> HouseholdInviteResponse:
        self._require_owner(household_id, actor_uid)
        if not payload.email and not payload.phone:
            raise ValueError("email_or_phone_required")
        now = _utcnow()
        token = uuid4().hex
        invite = HouseholdInviteResponse(
            id=str(uuid4()),
            household_id=household_id,
            name=payload.name.strip(),
            email=payload.email,
            phone=payload.phone,
            role=payload.role,
            token=token,
            status="pending",
            invited_by_uid=actor_uid,
            created_at=now,
            updated_at=now,
            invite_link=f"https://mekasa.app/invite/{token}",
        )
        with self._lock:
            self._invites[invite.id] = invite
        return invite

    def list_invites(self, household_id: str, actor_uid: str) -> list[HouseholdInviteResponse]:
        self._require_owner(household_id, actor_uid)
        return sorted(
            [invite for invite in self._invites.values() if invite.household_id == household_id],
            key=lambda item: item.created_at,
            reverse=True,
        )

    def accept_invite(
        self, token: str, actor_uid: str, actor_name: str | None
    ) -> HouseholdMemberResponse:
        with self._lock:
            invite = next((item for item in self._invites.values() if item.token == token), None)
            if invite is None:
                raise KeyError(token)
            if invite.status != "pending":
                raise ValueError("invite_not_pending")
            now = _utcnow()
            member = HouseholdMemberResponse(
                uid=actor_uid,
                household_id=invite.household_id,
                name=actor_name or invite.name,
                email=invite.email,
                phone=invite.phone,
                role=invite.role,
                status="active",
                created_at=now,
                updated_at=now,
            )
            bucket = self._members.setdefault(invite.household_id, {})
            bucket[actor_uid] = member
            self._invites[invite.id] = invite.model_copy(
                update={"status": "accepted", "updated_at": now}
            )
            return member

    def update_role(
        self,
        household_id: str,
        member_uid: str,
        actor_uid: str,
        payload: HouseholdMemberRoleUpdateRequest,
    ) -> HouseholdMemberResponse:
        self._require_owner(household_id, actor_uid)
        with self._lock:
            member = self._members.get(household_id, {}).get(member_uid)
            if member is None:
                raise KeyError(member_uid)
            if member.uid == actor_uid and payload.role != "owner":
                raise ValueError("cannot_demote_self")
            updated = member.model_copy(
                update={"role": payload.role, "updated_at": _utcnow()}
            )
            self._members[household_id][member_uid] = updated
            return updated


_members_repo: InMemoryMembersRepository | None = None


def get_members_repository() -> MembersRepository:
    """Process-wide members repository (in-memory for now)."""
    global _members_repo
    if _members_repo is None:
        _members_repo = InMemoryMembersRepository()
    return _members_repo


def reset_members_repository() -> None:
    """Reset for tests."""
    global _members_repo
    _members_repo = InMemoryMembersRepository()
