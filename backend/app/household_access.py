"""Shared household membership checks (REQ-019 + shared inventory ACL)."""

from __future__ import annotations

from app.models import HouseholdResponse
from app.repository import get_household_repository


def get_household_or_404(household_id: str) -> HouseholdResponse:
    household = get_household_repository().get(household_id)
    if household is None:
        raise KeyError(household_id)
    return household


def is_household_owner(household: HouseholdResponse, actor_uid: str) -> bool:
    if household.owner_uid == actor_uid:
        return True
    from app.members_repository import get_members_repository

    return get_members_repository().has_role(household.id, actor_uid, role="owner")


def assert_household_member(household_id: str, actor_uid: str) -> HouseholdResponse:
    """Owner or active member may access household data."""
    household = get_household_or_404(household_id)
    if household.owner_uid == actor_uid:
        return household
    from app.members_repository import get_members_repository

    if get_members_repository().is_active_participant(household_id, actor_uid):
        return household
    raise PermissionError(household_id)


def assert_household_owner(household_id: str, actor_uid: str) -> HouseholdResponse:
    """Household document owner or member with owner role."""
    household = get_household_or_404(household_id)
    if is_household_owner(household, actor_uid):
        return household
    raise PermissionError(household_id)


def can_mark_purchased(household_id: str, actor_uid: str) -> bool:
    """
    REQ-014: owners (and future buyer permission) may mark list items purchased.
    """
    household = get_household_or_404(household_id)
    if is_household_owner(household, actor_uid):
        return True
    from app.members_repository import get_members_repository

    return get_members_repository().has_permission(household_id, actor_uid, "buyer")


def assert_can_mark_purchased(household_id: str, actor_uid: str) -> HouseholdResponse:
    household = get_household_or_404(household_id)
    if can_mark_purchased(household_id, actor_uid):
        return household
    raise PermissionError(household_id)
