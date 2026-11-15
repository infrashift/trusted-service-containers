---
id: "01a1dbd5-3dc3-738a-bd4c-cb1b95d4e8b8"
title: "chit"
type: "image"
tags:
  - "image"
  - "chit"
  - "build"
  - "first-party"
created: "2026-11-14T14:52:27-06:00"
timestamp: "2026-11-15T04:57:55-06:00"
description: "The infrashift chat service: chitd and chit-reconcile with their CUE and SQL migrations, built first-party from a pinned infrashift commit onto ubi9-micro."
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-11-15T04:57:55-06:00"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/versions.json"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/Containerfiles/chit.Containerfile"
    title: "chit.Containerfile"
  - resource: "https://github.com/infrashift/chit/blob/1af19e66764dbe985f497d1e1997e057a1738595/deploy/Containerfile"
    title: "chit deploy/Containerfile"
---

# chit

Chit is the infrashift chat service. The image holds the server `chitd` and the job `chit-reconcile`. We build it from our own pinned commit, and no vendor image of it exists.

## Track

Build track. We compile `chitd` and `chit-reconcile` from the pinned `sources.chit` commit onto our `ubi9-micro` base, with `Containerfiles/chit.Containerfile`. See [Build track](/architecture/build-track--01a18382f2d2.md).

Chit publishes no release tags. Thus `sources.chit.ref` is the Go pseudo-version of the pinned commit, and the track admits only that shape. A person bumps `commit` and `ref` together, in a reviewed pull request.

## Trust class and provenance mode

`internal`. The upstream signature that we verify is the signature of our `ubi9-micro` base. See [Upstream trust classes](/architecture/upstream-trust-classes--01a18382f3fb.md).

The entry declares `firstParty`, because infrashift is the only publisher of Chit. No binary cross-check runs. See [ADR-008: A first-party build declares that no vendor binary exists](/decisions/adr-008-a-first-party-build-declares-that-no-vendor-binary-exists--01a1dbc581d4.md).

## Enforcement

See `versions.json` for the current value. On 2026-11-14 the value was `observe`.

## One image for the server and the job

The image holds two binaries and two data directories:

| Path | What it is |
|---|---|
| `/usr/bin/chitd` | The server. It is the entrypoint. Port 8065. |
| `/usr/bin/chit-reconcile` | The one-shot job that writes the grants of `auth/*.cue` to Keto. |
| `/etc/chit/auth` | The CUE that both binaries read. `CHIT_COMMANDS_CUE_DIR` points to it. |
| `/usr/share/chit/migrations` | The SQL migrations of the pinned commit, for a `golang-migrate` job. |

We put the server and the job in one image, as the `deploy/Containerfile` of Chit does. Then the job and the server read the same CUE from the same commit. Two images could get two different commits. We do not build `chit-mcp` and `chit-claude`. They are client tools, not server components.

Chit has no migration binary. A deployment runs `golang-migrate` against `/usr/share/chit/migrations`. No TSC image of `golang-migrate` exists.

## Runtime

* Port: 8065.
* Command: `chitd`. The server needs `CHIT_DATABASE_URL`.
* User: 1001, group 0, home `/home/chit`, with tzdata. The audit log directory `/var/log/chit` is writable.
* Build: `CGO_ENABLED=0`, `GOWORK=off`, `-trimpath`, `-s -w`, `GOTOOLCHAIN=local`.
* Chit has no version variable. The entry sets `noVersionSymbol` and an empty `ldflagsVars`, and the build passes no `-X`. The Go build info has the module version and `vcs.revision`.

## Attachments and the membership hook

The pin `1af19e66` (2026-11-15) adds two features that HALO needs:

* File attachments. `pkg/imagecheck` checks and re-encodes uploaded images. `internal/blob` stores the files in an S3-compatible store, for example the [seaweedfs](/images/seaweedfs--01a183832ee2.md) image. Migration `000009_files` adds the tables.
* The membership policy hook. Before `chitd` adds a member to a channel, it asks a hook URL. It gets a token for the hook with the OAuth2 client credentials flow.

Both features are pure Go. They need no cgo, no file in the image and no new directory. Both features are off when their URL is empty. The deployment sets `CHIT_S3_ENDPOINT` with the bucket, region and keys, and `CHIT_MEMBERSHIP_HOOK_URL` with the token URL, client ID and client secret.

## Smoke tests on 2026-11-14

We ran these tests on the local amd64 image:

1. `chitd` without `CHIT_DATABASE_URL` stopped with "CHIT_DATABASE_URL is required".
2. In the builder stage, `chit-reconcile` loaded the CUE of the commit (5 commands, 3 roles). Then it failed on a closed Keto port, as expected.
3. `migrate up` applied the 7 migrations from `/usr/share/chit/migrations` of the image to PostgreSQL 17.
4. `chitd` on that database loaded 5 slash commands, opened `/var/log/chit/audit.log` as UID 1001, and answered `GET /api/v1/system/ping` with `{"status":"OK"}`. An unauthenticated request got 401.

## Smoke tests and scan on 2026-11-15

We built the pin `1af19e66` for amd64 on the local machine:

1. In the builder stage, `chitd` stopped with "CHIT_DATABASE_URL is required", and `chit-reconcile` loaded the CUE (5 commands, 3 roles).
2. The image has 18 files in `/usr/share/chit/migrations`: 9 up and 9 down migrations.
3. `grype --fail-on critical` and `grype --only-fixed --fail-on high` both passed. The grype database was built on 2026-11-15. The image has no Critical and no High finding.

## Issues

* [The Chit pin has 9 Critical and 24 fixable High Go module findings](/issues/the-chit-pin-has-9-critical-and-24-fixable-high-go-module-findings--01a1dbd53dd3.md)

## Related

* [keto-cue](/images/keto-cue--01a1dbce4e47.md): the relation store that `chit-reconcile` writes to in HALO.
* [Build track](/architecture/build-track--01a18382f2d2.md)
* [Required labels on built images](/architecture/required-labels-on-built-images--01a18382f2eb.md)
* [Images overview](/images/images-overview--01a1837da526.md)
