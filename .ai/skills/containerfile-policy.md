# Containerfile policy

**Build track only.** Mirror-track images have no Containerfile and receive no
labels of ours — adding one would change the digest.

`scripts/lint-containerfiles.sh` enforces all of this and cross-checks every
runtime declaration against `versions.json`.

## Shape

Three stages, all digest-pinned through build args:

- **builder** — the Go toolchain, compiling from the pinned source commit
- **certs** — a ubi9-minimal donor for the CA trust bundle
- **runtime** — our ubi9-micro

## Re-declare ARGs after the runtime FROM

ARGs before the first `FROM` are global build args and are **not in scope**
inside a stage, so the labels expand to empty strings. A real bug the reference
had to fix. Caught by the lint and by `BUILD_LABEL_EMPTY`.

## What ubi9-micro lacks

Verified by listing the layer, and compensated for in every Containerfile:

| missing | consequence | fix |
|---|---|---|
| CA trust bundle | every outbound TLS call fails `x509: certificate signed by unknown authority` | copy from the `certs` stage, plus the two conventional symlinks and `SSL_CERT_FILE` |
| tzdata | `time.LoadLocation()` fails for anything but UTC | copy `/usr/share/zoneinfo` from the builder |
| UID 1001 in `/etc/passwd` | `os/user` lookups fail, `$HOME` unset | append the entry (no shadow-utils, so no `useradd`) |

It *does* have `bash` and coreutils, so `RUN` works and in-image smoke tests are
possible. Only the package manager is absent.

Assert the copied bundle is >100000 bytes: a truncated donor would ship an image
that fails TLS only in production.

## Non-root, group 0

`USER 1001` must be the **last** instruction, with GID 0 and `chmod -R g=u` on
owned directories, so the image works under OpenShift's arbitrary-UID SCC.

## Five required labels

`org.opencontainers.image.{source,revision,version}` plus
`io.infrashift.image.upstream.{digest,source}`. The policy denies without them.

## No hardcoded digests

`versions.json` is the only place a digest lives. The lint fails on any
`sha256:` literal in a Containerfile instruction.
