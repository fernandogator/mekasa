"""
Signed photo links with a per-instance cache (REQ-023).

Browsers cannot attach the bearer token to an `<img>` request, so the web app
asks for short-lived V4 signed Cloud Storage URLs instead. Signing on Cloud
Run is an IAM `signBlob` round trip, and a fresh URL defeats the browser's
image cache, so each instance keeps the links it has signed and hands the same
one back while it still has at least `MIN_REMAINING` left.

The cache only skips signing. Membership and ownership are checked on every
call by the router before any link is looked up (AC2).

Satisfies: REQ-023 (Signed Photo Links With a Server-Side Cache)
Acceptance criteria: AC3, AC4
Spec version: 1.0
"""

from __future__ import annotations

from collections import OrderedDict
from collections.abc import Callable
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from threading import Lock

LINK_TTL = timedelta(minutes=60)
MIN_REMAINING = timedelta(minutes=15)
CACHE_MAX_ENTRIES = 5000


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


@dataclass(frozen=True)
class PhotoLink:
    """A URL the browser can load directly; `expires_at` is None for unsigned local paths."""

    url: str
    expires_at: datetime | None


@dataclass(frozen=True)
class LinkLookup:
    link: PhotoLink | None
    cached: bool


class SignedLinkCache:
    """
    Least-recently-used map of (bucket, object) → signed link (AC4).

    A link with less than `min_remaining` left counts as a miss, so callers
    always get at least that much validity.
    """

    def __init__(
        self,
        max_entries: int = CACHE_MAX_ENTRIES,
        min_remaining: timedelta = MIN_REMAINING,
        clock: Callable[[], datetime] = _utcnow,
    ) -> None:
        self._entries: OrderedDict[tuple[str, str], PhotoLink] = OrderedDict()
        self._max_entries = max_entries
        self._min_remaining = min_remaining
        self._clock = clock
        self._lock = Lock()

    def get(self, key: tuple[str, str]) -> PhotoLink | None:
        with self._lock:
            link = self._entries.get(key)
            if link is None:
                return None
            if link.expires_at is not None and link.expires_at - self._clock() < self._min_remaining:
                del self._entries[key]
                return None
            self._entries.move_to_end(key)
            return link

    def put(self, key: tuple[str, str], link: PhotoLink) -> None:
        with self._lock:
            self._entries[key] = link
            self._entries.move_to_end(key)
            while len(self._entries) > self._max_entries:
                self._entries.popitem(last=False)

    def evict(self, key: tuple[str, str]) -> None:
        with self._lock:
            self._entries.pop(key, None)

    def __len__(self) -> int:
        with self._lock:
            return len(self._entries)


class GcsSigningCredentials:
    """
    Runtime credentials for V4 signing. On Cloud Run they hold no private key,
    so signing goes through IAM `signBlob`: the service account needs
    `roles/iam.serviceAccountTokenCreator` on itself.
    """

    def __init__(self) -> None:
        self._credentials = None
        self._lock = Lock()

    def current(self) -> tuple[str, str]:
        import google.auth
        from google.auth.transport.requests import Request

        with self._lock:
            if self._credentials is None:
                self._credentials, _ = google.auth.default(
                    scopes=["https://www.googleapis.com/auth/cloud-platform"]
                )
            if not self._credentials.valid:
                self._credentials.refresh(Request())
            return self._credentials.service_account_email, self._credentials.token


class CachedGcsSigner:
    """Signs `GET` links for one bucket, reusing cached links (AC3, AC4)."""

    def __init__(
        self,
        bucket,
        cache: SignedLinkCache,
        credentials: GcsSigningCredentials | None = None,
        clock: Callable[[], datetime] = _utcnow,
    ) -> None:
        self._bucket = bucket
        self._cache = cache
        self._credentials = credentials or GcsSigningCredentials()
        self._clock = clock

    def _key(self, object_name: str) -> tuple[str, str]:
        return (self._bucket.name, object_name)

    def link(self, object_name: str) -> LinkLookup:
        key = self._key(object_name)
        cached = self._cache.get(key)
        if cached is not None:
            return LinkLookup(cached, cached=True)
        blob = self._bucket.blob(object_name)
        if not blob.exists():
            return LinkLookup(None, cached=False)
        email, token = self._credentials.current()
        expires_at = self._clock() + LINK_TTL
        url = blob.generate_signed_url(
            version="v4",
            expiration=LINK_TTL,
            method="GET",
            service_account_email=email,
            access_token=token,
        )
        link = PhotoLink(url=url, expires_at=expires_at)
        self._cache.put(key, link)
        return LinkLookup(link, cached=False)

    def evict(self, object_name: str) -> None:
        self._cache.evict(self._key(object_name))


_cache = SignedLinkCache()


def shared_link_cache() -> SignedLinkCache:
    """One cache per process, shared by the product and item photo stores."""
    return _cache
