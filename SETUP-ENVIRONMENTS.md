# Setup runbook

Everything here must be done once, by a human, before the pipeline can run.
Work top to bottom; later steps depend on earlier ones.

Set these first:

```bash
export ORG=infrashift
export REPO=trusted-service-containers
export SLUG="${ORG}/${REPO}"
```

---

## 0. Preconditions

```bash
gh auth status          # needs admin:org, repo, write:packages
cosign version          # v2.6.1, matching tools.lock
regctl version
opa version             # v1.19.1
jq --version
```

The cosign version matters more than it looks. **cosign v3 defaults to
`--new-bundle-format=true`** and writes attestations as OCI referrers, while v2
writes legacy `sha256-<digest>.att` tags. The sibling repo
`infrashift/trusted-base-images` is on v2, so `internal`-class verification
reads the v2 layout. `tools.lock` pins v2.6.1 for that reason. **Migrate both
repos together or not at all.**

---

## 1. Run the blocking spike first

Do this before anything else. It decides the cosign pin, and if it fails the
mirror track's core value proposition does not hold.

```bash
docker login ghcr.io
regctl image copy \
  docker.io/sonatype/nexus3@sha256:3d6454ebafb3e807782c15dc9a500b83013107128e35db5da219fda05c07b68c \
  ghcr.io/<you>/spike/nexus3:probe --referrers --digest-tags --force-recursive
regctl artifact list ghcr.io/<you>/spike/nexus3:probe
```

GHCR has historically not implemented the OCI 1.1 `/referrers` API; regclient
and cosign both fall back to a tag schema. Every `regctl image copy` in this
repo passes **both** `--referrers` and `--digest-tags` so it works either way,
but confirm attestations survive the round trip before trusting the pipeline.

While you are there, get the day-one CVE numbers. Everything about the
exception workflow depends on them, and guessing produces either overkill or
something hopelessly undersized:

```bash
grype docker.io/sonatype/nexus3:3.90.5-ubi -o json | \
  jq '[.matches[].vulnerability.severity] | group_by(.) | map({(.[0]): length}) | add'
```

Expect nexus3 to quarantine. It is a ~700 MB JVM image: a UBI base, a JDK, and
several hundred bundled jars. It is onboarded with `enforcement: "observe"` in
`versions.json` precisely so it can be triaged without red-lighting `main`.

---

## 2. Create the repository

```bash
gh repo create "$SLUG" --private --source . --remote origin --push
```

---

## 3. Generate three cosign keypairs

**In `/dev/shm`, never in a git working tree.** The reference repo has three
live private keys sitting in `temp-delete/` in its checkout; treat those as
compromised and rotate them.

```bash
WORK=$(mktemp -d -p /dev/shm keygen.XXXXXX)
cd "$WORK"
for actor in build review release; do
  COSIGN_PASSWORD="$(openssl rand -base64 48)"
  export COSIGN_PASSWORD
  cosign generate-key-pair
  mv cosign.key "${actor}.key"
  mv cosign.pub "${actor}.pub"
  printf '%s' "$COSIGN_PASSWORD" > "${actor}.password"
  unset COSIGN_PASSWORD
done
ls -l
```

> `cosign generate-key-pair` produces **ECDSA P-256, not ED25519**. The
> reference repo's docs claim ED25519 throughout and are simply wrong. An
> inaccurate cryptographic claim in a supply-chain repo is worse than a boring
> accurate one, so say ECDSA P-256.

---

## 4. Three environments, each with TWO secrets

```bash
gh api -X PUT "repos/${SLUG}/environments/Build-Actor"
gh api -X PUT "repos/${SLUG}/environments/Review-Actor"
gh api -X PUT "repos/${SLUG}/environments/Release-Actor"

cd "$WORK"
for actor in build review release; do
  case $actor in
    build)   ENVNAME=Build-Actor   ;;
    review)  ENVNAME=Review-Actor  ;;
    release) ENVNAME=Release-Actor ;;
  esac
  gh secret set COSIGN_PRIVATE_KEY --repo "$SLUG" --env "$ENVNAME" < "${actor}.key"
  gh secret set COSIGN_PASSWORD    --repo "$SLUG" --env "$ENVNAME" < "${actor}.password"
done
```

> **`COSIGN_PASSWORD` is required and the reference runbook omits it entirely.**
> A generated key is an encrypted PEM; `cosign sign --key env://COSIGN_PRIVATE_KEY`
> cannot decrypt it without the password. Following the reference verbatim gives
> an opaque decryption failure on the first signing run.

All three secrets share the name `COSIGN_PRIVATE_KEY` deliberately. Every
script says `env://COSIGN_PRIVATE_KEY` and is identity-agnostic; which key a job
receives is decided **solely** by its `environment:` binding, which is
CODEOWNERS-protected. `scripts/lint-workflows.sh` fails if any job touches
`COSIGN_PRIVATE_KEY` without one.

### Protection rules

`Review-Actor` gets **Required Reviewers**. This is the human gate, and it is
the *entire* human gate:

```bash
REVIEWER_ID=$(gh api "users/<your-login>" --jq .id)
gh api -X PUT "repos/${SLUG}/environments/Review-Actor" \
  -F 'wait_timer=0' -F 'prevent_self_review=true' \
  -f 'reviewers[][type]=User' -F "reviewers[][id]=${REVIEWER_ID}"
```

`prevent_self_review=true` matters: without it the PR author approves their own
deployment and the gate is decorative.

Because the Review key is unreachable until a human approves that deployment, a
Review-Actor signature **is** proof the approval happened. That is why there is
no separate human signing key here. The reference's `human.pub` / `.sig2` scheme
requires a person to run `cosign sign-blob` by hand for every image, which is
why `human.pub` was never created and two of its scripts have been broken since
day one.

`Release-Actor` is restricted to `main`:

```bash
gh api -X PUT "repos/${SLUG}/environments/Release-Actor" \
  -F 'deployment_branch_policy[protected_branches]=false' \
  -F 'deployment_branch_policy[custom_branch_policies]=true'
gh api -X POST "repos/${SLUG}/environments/Release-Actor/deployment-branch-policies" \
  -f 'name=main' -f 'type=branch'
```

---

## 5. Publish public keys, destroy private ones

```bash
cp "$WORK"/{build,review,release}.pub .github/pdp/public-keys/
git add .github/pdp/public-keys/ && git commit -S -m "Add PDP public keys"

cd "$WORK"
shred -uzn 3 ./*.key ./*.password 2>/dev/null || rm -f ./*.key ./*.password
cd / && rm -rf "$WORK"
```

Verify nothing escaped:

```bash
cd /path/to/repo
git ls-files | grep -E '\.(key|pem)$' && echo "STOP" || echo "clean"
gitleaks detect --config .gitleaks.toml --redact --exit-code 1
```

---

## 6. Docker Hub OIDC connection

In the Docker Admin Console (needs Team/Business/DHI):

1. **Security → OIDC connections → Create**
2. Provider: `https://token.actions.githubusercontent.com`
3. Create a **ruleset** scoped as tightly as the console allows — ideally to the
   `Build-Actor` *environment* claim rather than a branch:
   `repo:infrashift/trusted-service-containers:environment:Build-Actor`
4. **Grant `pull` only.** This identity never pushes anywhere.
5. Note the connection ID.

```bash
gh variable set DOCKERHUB_ORGANIZATION     --repo "$SLUG" --body "infrashift"
gh variable set DOCKERHUB_OIDC_CONNECTIONID --repo "$SLUG" --body "<connection-id>"
```

Variables, not secrets — neither value is sensitive, and having them in logs
aids debugging.

Authenticate for `docker.io` too, even though `sonatype/nexus3` is public:
anonymous Docker Hub pulls are rate-limited per IP and GitHub runners share
IPs, so an anonymous mirror fails intermittently in a way that reads like a
network flake.

> **Unresolved:** whether the OIDC connection also covers
> `registry.scout.docker.com`, where DHI keeps its signed attestations. Docker's
> own mirror docs use an Organization Access Token for all three hosts. Test it;
> if OIDC works, one long-lived credential disappears. If not, add
> `DOCKERHUB_OAT` as a secret and use it for Scout only.

---

## 7. Resolve the four DHI digests

`versions.json` ships them as `sha256:0000…` placeholders. `make validate`
warns about them, and `scripts/mirror-leg.sh` **refuses to run** rather than
mirroring a fake pin.

```bash
docker login dhi.io
for REF in traefik:3-debian13 traefik:3-debian13-dev postgres:16-debian postgres:16-debian-dev; do
  printf '%-28s ' "$REF"
  regctl manifest head --format '{{.GetDescriptor.Digest}}' "dhi.io/${REF}"
done
```

Use `regctl manifest head`, **not** `docker pull` + `docker inspect` — the
latter returns the single-platform digest for your local architecture, not the
index digest we pin.

While logged in, discover the attestation repository and record it in each DHI
entry's `attestationRepo` (it currently says `DISCOVER_AT_BOOTSTRAP`):

```bash
docker scout attest list dhi.io/traefik:3-debian13
regctl artifact list --external registry.scout.docker.com/<org>/traefik dhi.io/traefik@<pin>
```

**Capture the full JSON output.** `scripts/mirror-leg.sh` tries both
`.manifests[]` and `.Manifests[]` spellings; confirm which is real rather than
leaving it to chance. An empty list is already a hard failure, so this fails
safe — but confirm it.

---

## 8. Verify the base-image assumptions

The Containerfiles compensate for three things ubi9-micro lacks. Re-check
against the digest you actually pin, because the base is rebuilt weekly:

```bash
BASE=ghcr.io/infrashift/trusted-base-images/trusted/ubi9-micro
D=$(jq -r '.bases["ubi9-micro"].amd64.digest' versions.json)
buildah unshare -- bash -c "
  c=\$(buildah from ${BASE}@${D}); m=\$(buildah mount \$c)
  for p in /etc/ssl/certs/ca-certificates.crt /etc/pki/tls/certs/ca-bundle.crt \\
           /etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem /etc/ssl/cert.pem; do
    [ -e \"\$m\$p\" ] && echo \"PRESENT \$p\" || echo \"ABSENT  \$p\"; done
  ls \"\$m/usr/share/zoneinfo/UTC\" >/dev/null 2>&1 && echo TZ-PRESENT || echo TZ-ABSENT
  grep -E '^[^:]*:x:1001:' \"\$m/etc/passwd\" || echo 'NO UID 1001'
  buildah umount \$c >/dev/null; buildah rm \$c >/dev/null"
```

Verified 2026-08-18: all four cert paths **absent**, tzdata **absent**, no UID
1001, but `bash` and coreutils **present**. If a cert path is unexpectedly
present, drop the `certs` donor stage rather than shipping a redundant bundle
that then diverges from the base's own.

---

## 9. Teams and CODEOWNERS

```bash
for t in platform-engineers security-admins devops-leads; do
  gh api "orgs/${ORG}/teams/${t}" --jq .slug || echo "MISSING: $t"
done
```

All three must exist **and have repository access**, or CODEOWNERS matches
nothing and "require review from Code Owners" is a silent no-op — with no way to
tell from the repo. The reference references three teams and gives no way to
check.

---

## 10. Branch ruleset on `main`

Require a PR with 1 approval, dismiss stale approvals, require Code Owner
review, require conversation resolution, block force pushes, require linear
history and signed commits, and use an **empty bypass list** — not org admins,
not repo admins.

Required status checks:

| Context | From |
|---|---|
| `review/cve-policy` | seeded by `pr-gate.yml`, resolved by `review.yml` |
| `build/gate` | `build.yml` aggregate job |
| `Repo Gate` | `pr-gate.yml` |

**Never make individual matrix legs required checks.** Job names change with the
matrix, and a required context that stops reporting blocks every PR forever.
That is why `build.yml` has a single aggregate `gate` job with `if: always()`.

Keep **"Allow GitHub Actions to create and approve pull requests" DISABLED.**
Not an oversight — the same flag would let a workflow satisfy a required
approval. The drift workflows are designed around it: they push a branch and
upsert a tracking issue, and a human opens the PR.

---

## 11. First run

```bash
make -f Ops.mk validate      # everything green before you push
make -f Ops.mk verify-pins   # re-resolve every pin against the live registries
```

Open a PR bumping one nexus3 digest. Expect exactly one mirror leg to run, a PR
comment with per-platform CVE tables, and `review/cve-policy` to resolve.

Read the actual grype output **before** writing any exception.
`.github/pdp/exceptions.yaml` ships empty on purpose.

---

## Checklist

- [ ] Referrers spike passed; `tools.lock` cosign pin confirmed
- [ ] Three environments exist, each with exactly two secrets
- [ ] Zero repository-level `COSIGN_PRIVATE_KEY`
- [ ] `Review-Actor` has Required Reviewers with `prevent_self_review`
- [ ] `Release-Actor` restricted to `main`
- [ ] Three `.pub` files committed; zero `.key` files anywhere
- [ ] Two repository variables set; OIDC ruleset scoped to pull-only
- [ ] Four DHI digests resolved; `attestationRepo` discovered and committed
- [ ] ubi9-micro assumptions re-verified against the pinned digest
- [ ] Three teams exist with repository access
- [ ] `main` ruleset active, empty bypass list, three required contexts
- [ ] `make -f Ops.mk validate` green
