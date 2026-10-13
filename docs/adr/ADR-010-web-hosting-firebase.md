# ADR-010: Firebase Hosting for the Web App

- **Status:** Accepted
- **Date:** 2026-10-13
- **Author:** Fernando Guerrero (with Claude Opus 5.5)
- **Related:** ADR-002 (`docs/architecture.md` §5 — the REST API keeps
  future desktop and web clients SDK-free), `firebase.json`,
  `backend/scripts/deploy-cloud-run.sh`,
  `.github/workflows/deploy-backend.yml`

## Context

Mekasa is adding a desktop web app alongside the iOS and Android
clients. Its design starts in Superdesign; this record only decides
where the built app is served from in GCP.

The backend is the Cloud Run service `mekasa-api` (`us-central1`,
project `hackathon2025-472017`). That project already uses Firebase for
Auth and Firestore (`firebase.json`). The API verifies Firebase ID
tokens and has no CORS configuration.

## Decision

Host the web app on **Firebase Hosting** in the same project
(`hackathon2025-472017`).

- The app is built to static files and served from Firebase Hosting's
  CDN at `https://<project>.web.app`, with an optional custom domain
  (managed TLS).
- A Hosting rewrite sends `/v1/**` to the Cloud Run service
  `mekasa-api` in `us-central1`, so the browser calls the API on the
  same origin as the app. The API needs no CORS configuration for
  this path.
- Sign-in uses the Firebase Auth web SDK with the same providers as
  the mobile apps; the web domain is added to Auth's authorized
  domains. The backend's token verification is unchanged.
- Deploys run from a GitHub Actions workflow (`firebase deploy --only
  hosting`), alongside `deploy-backend.yml`. Pull requests can deploy
  to Hosting preview channels.

## Rationale

1. **No new servers.** A static single-page app needs only a CDN; the
   API stays on the existing Cloud Run service.
2. **Same origin, no CORS.** The rewrite keeps every API call on the
   app's domain, so the API's attack surface does not grow.
3. **Already in the project.** Firebase is set up for Auth and
   Firestore; Hosting is one more block in `firebase.json`.
4. **Cost.** A household app fits Firebase Hosting's free tier (10 GB
   stored, 360 MB/day transferred); Cloud Run cost is unchanged.
5. **Preview channels** give every pull request a temporary URL for
   review without extra infrastructure.

## Alternatives considered

| Option | Why not now |
|---|---|
| Second Cloud Run service serving the build (e.g. nginx) | Only worth it for server-side rendering or a single deploy mechanism; adds a container to build and run |
| Cloud Storage bucket + external HTTPS load balancer + Cloud CDN | Built for very high traffic or advanced edge rules; the load balancer alone costs about US$18/month |

## Consequences and constraints

- **60-second limit on rewritten requests.** Firebase Hosting times out
  requests it forwards to Cloud Run after 60 seconds. Any endpoint that
  can exceed that (for example receipt parsing, ADR-007) must be called
  on the Cloud Run URL directly, which requires CORS for the web
  origin on that endpoint only.
- **Auth-gated images.** Photo endpoints such as
  `/v1/product-photos/{uuid}` are auth-gated redirects to signed URLs.
  An `<img>` tag cannot send the Firebase ID token, so the web app must
  either fetch images with the token or the API must hand out
  short-lived signed URLs directly.
- The deploy service account needs `roles/firebasehosting.admin`
  (plus `roles/run.viewer` for the Cloud Run rewrite).
- No secrets in the web bundle: the Firebase web config is public by
  design; everything else stays behind the API (NFR-004).

## Follow-ups

- Add a `hosting` block and the `/v1/**` rewrite to `firebase.json`
  once the web app exists.
- Add a `deploy-web.yml` workflow and grant the deploy role.
- Decide the image approach above before building inventory views.
- Measure receipt-parse latency to confirm whether it needs the direct
  Cloud Run path.
