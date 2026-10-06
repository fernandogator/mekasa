"""Duplicate inventory items: grouping, survivor choice and merge plan (REQ-INV-021).

Pure functions over `InventoryItemResponse`; persistence lives in the repositories.
"""

from __future__ import annotations

from datetime import datetime, timezone

from app.catalog_repository import normalize_name
from app.category_icons import is_placeholder_url
from app.models import DuplicateReason, InventoryDuplicateGroup, InventoryItemResponse

_REASON_RANK: dict[DuplicateReason, int] = {"same_barcode": 0, "same_product": 1, "same_name": 2}
_EPOCH = datetime.min.replace(tzinfo=timezone.utc)


def _singular(word: str) -> str:
    if len(word) <= 3:
        return word
    if word.endswith("ies"):
        return word[:-3] + "y"
    if word.endswith(("xes", "ches", "shes", "sses", "zes", "oes")):
        return word[:-2]
    if word.endswith("s") and not word.endswith(("ss", "us", "is")):
        return word[:-1]
    return word


def dedupe_name(name: str) -> str:
    """
    Satisfies: REQ-INV-021 AC1
    Spec version: 1.0

    Case, accents, punctuation and spacing ignored; simple plurals reduced to
    the singular ("Bananas" → "banana", "Berries" → "berry", "Boxes" → "box").
    """
    return " ".join(_singular(word) for word in normalize_name(name).split())


def _keys(item: InventoryItemResponse) -> list[tuple[DuplicateReason, str]]:
    keys: list[tuple[DuplicateReason, str]] = []
    if (item.barcode or "").strip():
        keys.append(("same_barcode", item.barcode.strip()))
    if (item.product_id or "").strip():
        keys.append(("same_product", item.product_id.strip()))
    name = dedupe_name(item.name)
    if name:
        keys.append(("same_name", f"{normalize_name(item.category)}|{name}"))
    return keys


def has_real_image(item: InventoryItemResponse) -> bool:
    return bool((item.image_url or "").strip()) and not is_placeholder_url(item.image_url)


def _image_time(item: InventoryItemResponse) -> datetime:
    return item.image_updated_at or item.updated_at or _EPOCH


def pick_survivor(items: list[InventoryItemResponse]) -> InventoryItemResponse:
    """
    Satisfies: REQ-INV-021 AC2
    Spec version: 1.0

    Newest real picture wins; with no real picture, the most recently updated item.
    """
    with_image = [item for item in items if has_real_image(item)]
    if with_image:
        return max(with_image, key=lambda item: (_image_time(item), item.updated_at, item.id))
    return max(items, key=lambda item: (item.updated_at, item.id))


def find_groups(items: list[InventoryItemResponse]) -> list[InventoryDuplicateGroup]:
    """
    Satisfies: REQ-INV-021 AC1, AC2
    Spec version: 1.0

    Items linked through any chain of shared barcode, product or category+name
    form one group; the group's reason is the strongest rule that links it.
    """
    visible = [item for item in items if not item.deleted]
    parent = list(range(len(visible)))

    def root(i: int) -> int:
        while parent[i] != i:
            parent[i] = parent[parent[i]]
            i = parent[i]
        return i

    first_by_key: dict[tuple[DuplicateReason, str], int] = {}
    linked_by: dict[tuple[DuplicateReason, str], int] = {}
    for index, item in enumerate(visible):
        for key in _keys(item):
            if key in first_by_key:
                parent[root(index)] = root(first_by_key[key])
                linked_by[key] = first_by_key[key]
            else:
                first_by_key[key] = index

    members: dict[int, list[int]] = {}
    for index in range(len(visible)):
        members.setdefault(root(index), []).append(index)

    groups: list[InventoryDuplicateGroup] = []
    for indexes in members.values():
        if len(indexes) < 2:
            continue
        group_root = root(indexes[0])
        reasons = [reason for (reason, _), first in linked_by.items() if root(first) == group_root]
        reason = min(reasons, key=_REASON_RANK.__getitem__)
        group_items = sorted((visible[i] for i in indexes), key=lambda item: item.updated_at, reverse=True)
        groups.append(
            InventoryDuplicateGroup(reason=reason, keep_id=pick_survivor(group_items).id, items=group_items)
        )
    groups.sort(key=lambda group: (_REASON_RANK[group.reason], dedupe_name(group.items[0].name)))
    return groups


def is_one_group(items: list[InventoryItemResponse]) -> bool:
    """REQ-INV-021 AC4: every item belongs to the single group AC1 forms from them."""
    groups = find_groups(items)
    return len(groups) == 1 and len(groups[0].items) == len(items)


def merge_updates(survivor: InventoryItemResponse, others: list[InventoryItemResponse]) -> dict:
    """
    Satisfies: REQ-INV-021 AC3
    Spec version: 1.0

    Fields the survivor takes: the higher quantity and threshold (not a sum), and
    barcode, product, price and health filled from the most recently updated other
    item when the survivor has none.
    """
    group = [survivor, *others]
    updates: dict = {
        "quantity": max(item.quantity for item in group),
        "low_stock_threshold": max(item.low_stock_threshold for item in group),
    }
    newest_first = sorted(others, key=lambda item: item.updated_at, reverse=True)
    for field in ("barcode", "product_id", "price_paid", "health"):
        if getattr(survivor, field) not in (None, ""):
            continue
        donor = next((item for item in newest_first if getattr(item, field) not in (None, "")), None)
        if donor is not None:
            updates[field] = getattr(donor, field)
    return updates
