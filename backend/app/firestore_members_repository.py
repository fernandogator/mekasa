"""Firestore-backed household members + invites (REQ-019)."""

from __future__ import annotations

import logging
from datetime import datetime, timezone
from typing import Any
from uuid import uuid4

from google.cloud import firestore

from app.config import Settings
from app.firestore_retry import STREAM_RETRY
from app.models import (
    HouseholdInviteCreateRequest,
    HouseholdInviteResponse,
    HouseholdMemberResponse,
    HouseholdMemberRoleUpdateRequest,
    MemberAvoidUpdateRequest,
    member_role_sort_key,
)
from app.members_repository import invite_email_matches, normalize_avoid_list, normalize_email
from app.repository import get_household_repository

logger = logging.getLogger(__name__)

HOUSEHOLDS = "households"
MEMBERS = "members"
INVITES = "invites"
INVITE_TOKENS = "invite_tokens"
# Point reads only. Collection-group queries on invites need an index this
# project does not have, and that missing index was failing household load.
INVITE_EMAILS = "invite_emails"
USER_MEMBERSHIPS = "user_memberships"


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


def _member_from(household_id: str, uid: str, data: dict[str, Any]) -> HouseholdMemberResponse:
    raw_perms = data.get("permissions") or []
    permissions = [str(p) for p in raw_perms] if isinstance(raw_perms, list) else []
    raw_avoid = data.get("avoid") or []
    avoid = [str(a) for a in raw_avoid] if isinstance(raw_avoid, list) else []
    return HouseholdMemberResponse(
        uid=uid,
        household_id=household_id,
        name=data.get("name"),
        email=data.get("email"),
        phone=data.get("phone"),
        role=data.get("role") or "member",
        status=data.get("status") or "active",
        permissions=permissions,
        avoid=avoid,
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
        snap = ref.get()
        if snap.exists:
            data = snap.to_dict() or {}
            if data.get("role") == "owner" and data.get("status") == "active":
                return
            now = _utcnow()
            ref.update({"role": "owner", "status": "active", "updated_at": now})
            self._db.collection(USER_MEMBERSHIPS).document(owner_uid).collection(HOUSEHOLDS).document(
                household_id
            ).set({"role": "owner", "status": "active", "updated_at": now}, merge=True)
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
            for snap in self._members_col(household_id).stream(retry=STREAM_RETRY)
        ]
        return sorted(
            members,
            key=lambda item: (member_role_sort_key(item.role), item.name or item.uid),
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
            "email": normalize_email(payload.email) or payload.email,
            "email_lower": normalize_email(payload.email),
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
        normalized = data.get("email_lower")
        if normalized:
            try:
                self._index_pending_email(str(normalized), token, household_id, invite_id)
            except Exception:
                logger.exception("invite email index write failed")
        return _invite_from(household_id, invite_id, data)

    def list_invites(self, household_id: str, actor_uid: str) -> list[HouseholdInviteResponse]:
        self._require_owner(household_id, actor_uid)
        invites = [
            _invite_from(household_id, snap.id, dict(snap.to_dict() or {}))
            for snap in self._invites_col(household_id).stream(retry=STREAM_RETRY)
        ]
        return sorted(invites, key=lambda item: item.created_at, reverse=True)

    def accept_invite(
        self,
        token: str,
        actor_uid: str,
        actor_name: str | None,
        actor_email: str | None = None,
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
        if not invite_email_matches(invite.get("email"), actor_email):
            raise ValueError("invite_email_mismatch")
        household = get_household_repository().get(household_id)
        if household is not None and household.owner_uid == actor_uid:
            raise ValueError("already_in_household")
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
        normalized = normalize_email(invite.get("email") or invite.get("email_lower"))
        if normalized:
            try:
                email_ref = self._db.collection(INVITE_EMAILS).document(normalized)
                if email_ref.get().exists:
                    email_ref.update(
                        {f"pending.{token}": firestore.DELETE_FIELD, "updated_at": now}
                    )
            except Exception:
                logger.exception("invite email index cleanup failed")
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

    def update_avoid(
        self,
        household_id: str,
        member_uid: str,
        actor_uid: str,
        payload: MemberAvoidUpdateRequest,
    ) -> HouseholdMemberResponse:
        if member_uid == actor_uid:
            self._require_member_or_owner(household_id, actor_uid)
        else:
            self._require_owner(household_id, actor_uid)
        ref = self._members_col(household_id).document(member_uid)
        snap = ref.get()
        if not snap.exists:
            raise KeyError(member_uid)
        data = dict(snap.to_dict() or {})
        updates = {"avoid": normalize_avoid_list(payload.avoid), "updated_at": _utcnow()}
        data.update(updates)
        ref.update(updates)
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

    def accept_pending_invites_for_email(
        self, actor_uid: str, email: str | None, actor_name: str | None
    ) -> list[HouseholdMemberResponse]:
        normalized = normalize_email(email)
        if normalized is None:
            return []
        accepted: list[HouseholdMemberResponse] = []
        seen_tokens: set[str] = set()
        for snap in self._pending_invite_snaps(email.strip(), normalized):
            data = snap.to_dict() or {}
            if data.get("status") != "pending":
                continue
            token = data.get("token")
            if not token or token in seen_tokens:
                continue
            seen_tokens.add(str(token))
            try:
                accepted.append(
                    self.accept_invite(str(token), actor_uid, actor_name, actor_email=email)
                )
            except (KeyError, ValueError):
                continue
            except Exception:
                logger.exception("accept pending invite failed")
                continue
        try:
            accepted.extend(
                self._claim_accepted_invites(actor_uid, email.strip(), normalized, actor_name)
            )
        except Exception:
            logger.exception("claim accepted invite failed")
        return accepted

    def _claim_accepted_invites(
        self, actor_uid: str, raw_email: str, normalized: str, actor_name: str | None
    ) -> list[HouseholdMemberResponse]:
        claimed: list[HouseholdMemberResponse] = []
        for snap in self._accepted_invite_snaps(raw_email, normalized):
            data = snap.to_dict() or {}
            if data.get("status") != "accepted":
                continue
            household_id = snap.reference.parent.parent.id
            if self.is_active_participant(household_id, actor_uid):
                continue
            claimed.append(
                self._join_accepted_invite(household_id, data, actor_uid, actor_name)
            )
        return claimed

    def _join_accepted_invite(
        self,
        household_id: str,
        invite: dict[str, Any],
        actor_uid: str,
        actor_name: str | None,
    ) -> HouseholdMemberResponse:
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
        batch.set(
            self._db.collection(USER_MEMBERSHIPS)
            .document(actor_uid)
            .collection(HOUSEHOLDS)
            .document(household_id),
            {"role": member_data["role"], "status": "active", "updated_at": now},
        )
        batch.commit()
        return _member_from(household_id, actor_uid, member_data)

    def _accepted_invite_snaps(self, raw_email: str, normalized: str) -> list[Any]:
        ref = self._db.collection(INVITE_EMAILS).document(normalized)
        try:
            snap = ref.get()
        except Exception:
            logger.exception("accepted invite index read failed")
            return []
        data = snap.to_dict() if snap.exists else {}
        if data.get("scanned"):
            return self._snaps_from_invite_map(data.get("accepted") or {})
        found: list[Any] = []
        accepted_map: dict[str, dict[str, str]] = {}
        try:
            households = self._db.collection(HOUSEHOLDS).stream(retry=STREAM_RETRY)
            for household_snap in households:
                invites = household_snap.reference.collection(INVITES).stream(retry=STREAM_RETRY)
                for invite_snap in invites:
                    invite = invite_snap.to_dict() or {}
                    if invite.get("status") != "accepted":
                        continue
                    stored = normalize_email(invite.get("email_lower") or invite.get("email"))
                    raw_stored = str(invite.get("email") or "").strip()
                    if (
                        stored != normalized
                        and raw_stored != raw_email
                        and raw_stored.lower() != normalized
                    ):
                        continue
                    token = str(invite.get("token") or invite_snap.id)
                    accepted_map[token] = {
                        "household_id": household_snap.id,
                        "invite_id": invite_snap.id,
                    }
                    found.append(invite_snap)
        except Exception:
            logger.exception("accepted invite scan failed")
            return []
        try:
            self._save_accepted_scan(normalized, accepted_map)
        except Exception:
            logger.exception("accepted invite index write failed")
        return found

    def _snaps_from_invite_map(self, mapping: Any) -> list[Any]:
        if not isinstance(mapping, dict):
            return []
        snaps: list[Any] = []
        for meta in mapping.values():
            if not isinstance(meta, dict):
                continue
            household_id = meta.get("household_id")
            invite_id = meta.get("invite_id")
            if not household_id or not invite_id:
                continue
            invite_snap = self._invites_col(str(household_id)).document(str(invite_id)).get()
            if invite_snap.exists:
                snaps.append(invite_snap)
        return snaps

    def _save_accepted_scan(self, normalized: str, accepted_map: dict[str, dict[str, str]]) -> None:
        ref = self._db.collection(INVITE_EMAILS).document(normalized)
        transaction = self._db.transaction()

        @firestore.transactional
        def _run(transaction: firestore.Transaction) -> None:
            snap = ref.get(transaction=transaction)
            accepted: dict[str, Any] = {}
            if snap.exists:
                raw = (snap.to_dict() or {}).get("accepted") or {}
                if isinstance(raw, dict):
                    accepted = dict(raw)
            accepted.update(accepted_map)
            transaction.set(
                ref,
                {
                    "email": normalized,
                    "accepted": accepted,
                    "scanned": True,
                    "updated_at": _utcnow(),
                },
                merge=True,
            )

        _run(transaction)

    def _pending_invite_snaps(self, raw_email: str, normalized: str):
        """
        Pending invites for this email.

        New invites are stored at invite_emails/{email} and read by document id.
        Older invites have no such row, so those are found by reading each
        household's invites subcollection. That path does not need the
        collection-group index that was returning FAILED_PRECONDITION.
        """
        try:
            indexed = self._indexed_pending_snaps(normalized)
        except Exception:
            logger.exception("invite email index read failed")
            return
        if indexed is not None:
            yield from indexed
            return
        try:
            matches = self._scan_household_invites(raw_email, normalized)
        except Exception:
            logger.exception("legacy invite scan failed")
            return
        if not matches:
            try:
                self._ensure_empty_email_index(normalized)
            except Exception:
                logger.exception("empty invite email index write failed")
            return
        for snap in matches:
            data = snap.to_dict() or {}
            token = str(data.get("token") or "")
            household_id = snap.reference.parent.parent.id
            try:
                self._index_pending_email(normalized, token, household_id, snap.id)
            except Exception:
                logger.exception("invite email index write failed")
            yield snap

    def _indexed_pending_snaps(self, normalized: str) -> list[Any] | None:
        snap = self._db.collection(INVITE_EMAILS).document(normalized).get()
        if not snap.exists:
            return None
        pending = (snap.to_dict() or {}).get("pending") or {}
        if not isinstance(pending, dict):
            return []
        snaps: list[Any] = []
        for meta in pending.values():
            if not isinstance(meta, dict):
                continue
            household_id = meta.get("household_id")
            invite_id = meta.get("invite_id")
            if not household_id or not invite_id:
                continue
            invite_snap = self._invites_col(str(household_id)).document(str(invite_id)).get()
            if invite_snap.exists:
                snaps.append(invite_snap)
        return snaps

    def _scan_household_invites(self, raw_email: str, normalized: str) -> list[Any]:
        found: list[Any] = []
        seen: set[str] = set()
        for household_snap in self._db.collection(HOUSEHOLDS).stream(retry=STREAM_RETRY):
            invites = household_snap.reference.collection(INVITES).stream(retry=STREAM_RETRY)
            for invite_snap in invites:
                if invite_snap.id in seen:
                    continue
                data = invite_snap.to_dict() or {}
                if data.get("status") != "pending":
                    continue
                stored = normalize_email(data.get("email_lower") or data.get("email"))
                raw_stored = str(data.get("email") or "").strip()
                if stored != normalized and raw_stored != raw_email and raw_stored.lower() != normalized:
                    continue
                seen.add(invite_snap.id)
                found.append(invite_snap)
        return found

    def _index_pending_email(
        self, normalized: str, token: str, household_id: str, invite_id: str
    ) -> None:
        if not token:
            return
        ref = self._db.collection(INVITE_EMAILS).document(normalized)
        transaction = self._db.transaction()

        @firestore.transactional
        def _run(transaction: firestore.Transaction) -> None:
            snap = ref.get(transaction=transaction)
            pending: dict[str, Any] = {}
            if snap.exists:
                raw = (snap.to_dict() or {}).get("pending") or {}
                if isinstance(raw, dict):
                    pending = dict(raw)
            pending[token] = {"household_id": household_id, "invite_id": invite_id}
            transaction.set(
                ref,
                {"email": normalized, "pending": pending, "updated_at": _utcnow()},
            )

        _run(transaction)

    def _ensure_empty_email_index(self, normalized: str) -> None:
        ref = self._db.collection(INVITE_EMAILS).document(normalized)
        transaction = self._db.transaction()

        @firestore.transactional
        def _run(transaction: firestore.Transaction) -> None:
            snap = ref.get(transaction=transaction)
            if snap.exists:
                return
            transaction.set(
                ref,
                {"email": normalized, "pending": {}, "updated_at": _utcnow()},
            )

        _run(transaction)

    def preferred_household_id(self, actor_uid: str) -> str | None:
        snaps = list(
            self._db.collection(USER_MEMBERSHIPS)
            .document(actor_uid)
            .collection(HOUSEHOLDS)
            .stream(retry=STREAM_RETRY)
        )
        active = []
        for snap in snaps:
            data = snap.to_dict() or {}
            if data.get("status") == "active":
                active.append((snap.id, data.get("role") or "member", data.get("updated_at")))
        guests = [row for row in active if row[1] in ("teen", "member")]
        pool = guests or active
        if not pool:
            return None
        pool.sort(key=lambda row: row[2] or datetime.min.replace(tzinfo=timezone.utc), reverse=True)
        return pool[0][0]

    def primary_household_id_for_user(self, actor_uid: str) -> str | None:
        return self.preferred_household_id(actor_uid)
