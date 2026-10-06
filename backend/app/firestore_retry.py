"""
Retry policy passed to every Firestore query stream.

Satisfies: NFR-003 (resilience of household reads)
Spec version: 1.0

`Query.stream()` without an explicit `retry` looks up the transport's default
retry on a mid-stream error and crashes with
`AttributeError: '_UnaryStreamMultiCallable' object has no attribute '_retry'`
(google-cloud-firestore 2.21–2.34), hiding the real error. With an explicit
policy the stream resumes after the last document on transient errors and
re-raises the original error otherwise.
"""

from __future__ import annotations

from google.api_core import exceptions
from google.api_core import retry as retries

STREAM_RETRY = retries.Retry(
    predicate=retries.if_exception_type(
        exceptions.Aborted,
        exceptions.DeadlineExceeded,
        exceptions.InternalServerError,
        exceptions.ServiceUnavailable,
    ),
    initial=0.2,
    maximum=2.0,
    multiplier=2.0,
    timeout=20.0,
)
