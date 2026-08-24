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

## 6. Docker Hub authentication

**An Organization Access Token, on the `Build-Actor` environment.** OIDC was the
original design and is still the better end state; it is not what runs today,
and the reason is worth recording.

### Why the token, for now

The workflows previously logged in with `DOCKERHUB_OIDC_CONNECTIONID` and no
password. That variable was never set, so the first pull request to reach
`CI Build & Audit` failed at the first login with

    DOCKERHUB_OIDC_CONNECTIONID is required for Docker Hub OIDC login

and `Release Images` then refused to promote on the back of a failed build,
which is the gate behaving correctly.

OIDC has the better properties and they are not in dispute: a short-lived token
scoped to a claim like
`repo:infrashift/trusted-service-containers:environment:Build-Actor` cannot be
used from another repo, another environment, or a laptop, and there is nothing
to rotate or leak. A token has none of that.

What settled it is the open question this step used to end on: whether the OIDC
connection also covers `registry.scout.docker.com`, where DHI keeps its signed
attestations. Docker's own mirror documentation uses an access token for all
three hosts. Rather than keep the pipeline red while that is resolved in the
abstract, the token gets it green and turns the question into a measurement:
once it runs, the logs say which hosts accepted what.

**Revisit this.** If OIDC proves out for `dhi.io` and `docker.io`, move those two
back and leave the token for Scout alone -- one credential instead of three
hosts' worth.

### Create the token

Docker Admin Console → **Organization → Access tokens**. Organisation-scoped, not
personal: a personal token ties CI to one human's account, breaks when they
rotate credentials or leave, and attributes every mirror pull to them.

Grant **read-only**. This identity pulls upstream images and never pushes; our
own images go to GHCR with `GITHUB_TOKEN`.

### Install it

```bash
SLUG=infrashift/trusted-service-containers
gh variable set DOCKERHUB_ORGANIZATION --repo "$SLUG" --body "infrashiftio"
gh secret   set DOCKERHUB_OAT --repo "$SLUG" --env Build-Actor
```

`DOCKERHUB_ORGANIZATION` is a variable -- it is the org name, not a credential,
and having it in logs aids debugging.

**The Docker Hub organisation is `infrashiftio`, not `infrashift`.** The GitHub
org and the Docker Hub org are different names, and the variable holds the
Docker Hub one because it is used as the login username and nothing else. Set to
`infrashift` it authenticates as a user that does not exist, and Docker answers
`unauthorized: incorrect username or password` -- which reads like a bad token
and sends you looking at the secret. The token is a secret, and specifically an
**environment** secret on `Build-Actor`.

That last part is not incidental. A repository secret is readable by every job
in every workflow, so the release and review actors would gain a credential they
have no business holding -- the same separation the three cosign keys exist to
create, undone by one misplaced secret. The jobs that log in
(`build.yml`'s `mirror-and-audit` and `build-and-audit`, and
`drift-upstream.yml`'s `detect`) all bind to `Build-Actor`.

`drift-upstream.yml`'s `detect` job was bound to `Build-Actor` for exactly this
reason; it previously declared no environment. One consequence to keep in mind:
that workflow is **scheduled**, so if `Build-Actor` ever gains required
reviewers, its nightly runs will queue for approval instead of running. It has
none today.

Its `id-token: write` grant was removed at the same time. The comment beside it
said "Docker OIDC, so the DHI legs can be listed", and with token auth nothing in
that job consumes an OIDC token at all.

> **Still open, and now measurable:** whether OIDC covers
> `registry.scout.docker.com`. Answer it from a real run rather than from the
> documentation, then narrow the token's scope or retire it.

---

## 7. Resolve the four DHI digests

**Done — 2026-08-24.** Kept as the procedure for the next pin.

`versions.json` shipped them as `sha256:0000…` placeholders, and
`scripts/mirror-leg.sh` refuses to run rather than mirror a fake pin.

```bash
docker login dhi.io
for REF in traefik:3-debian13 traefik:3-debian13-dev postgres:16-debian postgres:16-debian-dev; do
  printf '%-28s ' "$REF"
  regctl manifest head --format '{{.GetDescriptor.Digest}}' "dhi.io/${REF}"
done
```

Use `regctl manifest head`, **not** `docker pull` + `docker inspect` — the latter
returns the single-platform digest for your local architecture, not the index
digest we pin. Confirm it with
`regctl manifest head --format '{{.GetDescriptor.MediaType}}'`: an index reports
`application/vnd.oci.image.index.v1+json`.

### Where the attestations actually live

This section used to say "discover the attestation repository and record it in
`attestationRepo`", and pointed at `docker scout attest list`. Both were wrong,
and the field is gone.

DHI publishes attestations as **OCI referrers in the image's own repository** —
`dhi.io/traefik`, not `registry.scout.docker.com/<org>/traefik`. There is no
separate attestation registry, so there was never a namespace to discover.
`attestationRepo` could only ever be set wrong, and was: it shipped as the
literal `DISCOVER_AT_BOOTSTRAP`, which failed as `repo must be lowercase`.

The structure, verified against the live registry:

| Level | Carries |
|---|---|
| index (what we pin) | a cosign signature referrer |
| each platform manifest | 15 in-toto attestation referrers |
| each attestation manifest | its own cosign signature referrer |

Two consequences the old code missed. The attestations hang off the **platform**
manifests, so listing referrers on the index finds only the signature — which is
why `requiredPredicates` appeared to be missing. And `regctl artifact list`
emits **`.descriptors[]`**; the earlier note here asked which of `.manifests` or
`.Manifests` was real, and the answer is neither.

### Verifying by hand

`--experimental-oci11=true` is not optional. DHI attaches signatures as OCI 1.1
referrers, while cosign looks for the legacy `sha256-<digest>.sig` tag by
default, so without the flag a correctly signed image reports
`no signatures found`:

```bash
cosign verify --key .github/pdp/keyring/dhi-latest.pub \
  --insecure-ignore-tlog=true --experimental-oci11=true \
  dhi.io/traefik@sha256:734fb24f3fbdf5e664fb750753e11edc54dcf99706b714612a66837466fd3ad8
```

Keep cosign at **v2**. v3 defaults `--new-bundle-format=true` and fails against
DHI's simplesigning payloads, so `tools.lock`'s existing "v2, not v3" pin matters
here specifically, not only for the `.att` layout.

The keyring is the right key, checked rather than assumed: the public key
embedded in the signature's Rekor bundle is byte-identical to
`.github/pdp/keyring/dhi-latest.pub`, and the live keyring at
`registry.scout.docker.com/keyring/dhi/latest.pub` still matches the committed
copy.

`docker scout` is not needed for any of this and the pipeline never calls it.
It was useful once, to discover the layout above; `regctl` does the same job.
Scout is also not a scanner here — our SBOMs come from syft and our CVE
assessment from grype. The DHI attestations answer a different question: what
the vendor signed.

Verified end to end on 2026-08-24 — traefik and postgres, both platforms, 15
referrers each, every signature verifying against the committed keyring and no
missing predicates.

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
- [ ] `DOCKERHUB_ORGANIZATION` variable set; `DOCKERHUB_OAT` read-only token on the `Build-Actor` environment
- [ ] Four DHI digests resolved; `attestationRepo` discovered and committed
- [ ] ubi9-micro assumptions re-verified against the pinned digest
- [ ] Three teams exist with repository access
- [ ] `main` ruleset active, empty bypass list, three required contexts
- [ ] `make -f Ops.mk validate` green
