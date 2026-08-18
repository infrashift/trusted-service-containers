# Registry authentication

Four logins, one credential path. `docker/login-action` writes
`~/.docker/config.json`, which `regctl`, `cosign`, `syft` and `grype` all read.

| registry | why |
|---|---|
| `dhi.io` | DHI image layers |
| `registry.scout.docker.com` | DHI **attestations** live here, not on dhi.io — a separate registry needing its own login |
| `docker.io` | sonatype/nexus3 and the build-track cross-check references |
| `ghcr.io` | our own push target (`GITHUB_TOKEN`) |

## OIDC, not a stored token

```yaml
- uses: docker/login-action@<sha>   # v4.6.0
  with:
    registry: dhi.io
    username: ${{ vars.DOCKERHUB_ORGANIZATION }}
  env:
    DOCKERHUB_OIDC_CONNECTIONID: ${{ vars.DOCKERHUB_OIDC_CONNECTIONID }}
```

No password input. Needs `id-token: write` **per job**, never at workflow level.
Requires v4.5.0 or later. Scope the Docker-side ruleset to pull only.

## Authenticate for docker.io even though nexus3 is public

Anonymous Docker Hub pulls are rate-limited per IP and GitHub runners share IPs.
An anonymous mirror fails intermittently in a way that reads like a network
flake.

## The base image needs no credential

`ghcr.io/infrashift/trusted-base-images/trusted/ubi9-micro` is anonymously
readable (verified). No PAT, no package-to-repo grant. If that ever changes, the
correct fix is the sibling's package settings → Manage Actions access, not a PAT.

## Unresolved

Whether the OIDC connection covers `registry.scout.docker.com`. Docker's own
mirror docs use an Organization Access Token for all three hosts. See
[`../../SETUP-ENVIRONMENTS.md`](../../SETUP-ENVIRONMENTS.md) §6.
