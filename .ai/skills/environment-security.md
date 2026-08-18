# Key isolation

Three GitHub Environments hold three different cosign keys under the **same**
secret name, `COSIGN_PRIVATE_KEY`. Isolation comes entirely from the
`environment:` binding on the job.

| environment | key | protection |
|---|---|---|
| `Build-Actor` | build | none — runs on every PR |
| `Review-Actor` | review | **Required Reviewers**, `prevent_self_review` |
| `Release-Actor` | release | `main` only, reviewers |

Every script says `env://COSIGN_PRIVATE_KEY` and is identity-agnostic. A script
cannot be pointed at the wrong key by editing the script — only by editing the
workflow's environment binding, which is CODEOWNERS-protected.
`scripts/lint-workflows.sh` fails if any job touches `COSIGN_PRIVATE_KEY`
without one.

## Two secrets per environment

`COSIGN_PRIVATE_KEY` **and** `COSIGN_PASSWORD`. A generated key is an encrypted
PEM and cannot be decrypted without the password. The reference stores only the
first, which cannot work.

## The Review signature IS the human approval

Because the Review key is unreachable until a named human approves that
deployment, a Review-Actor signature is proof the approval happened. There is
deliberately no separate human signing key: the reference's `human.pub`/`.sig2`
scheme requires a person to run `cosign sign-blob` by hand for every image,
which is why `human.pub` was never created and two of its scripts have been
broken since day one.

## Keys are ECDSA P-256

Not ED25519. `cosign generate-key-pair` has no key-type flag. Do not repeat the
reference's inaccurate claim.

## Never commit private key material

`.gitignore` covers `*.key` and `*.pem`; `.gitleaks.toml` has explicit rules for
PEM and Sigstore key blocks. Generate in `/dev/shm` and `shred` — see
[`../../SETUP-ENVIRONMENTS.md`](../../SETUP-ENVIRONMENTS.md) §3.
