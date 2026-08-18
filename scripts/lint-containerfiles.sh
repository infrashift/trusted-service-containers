#!/usr/bin/env bash
# Structural lint for the build-track Containerfiles.
#
# Eight near-identical files drift. The reference repo's six Containerfiles
# already differ in ways nobody intended. These checks make the shape
# mechanical, and cross-check every runtime declaration against versions.json
# so the two cannot disagree.
#
# Mirror-track images have NO Containerfile and no labels of ours: we never
# alter a mirrored image, because that would change its digest.
set -euo pipefail

python3 - <<'PY'
import json, os, re, sys

V = json.load(open('versions.json'))
fail = []
def err(f, m): fail.append(f"{f}: {m}")

REQUIRED_LABELS = [
    "org.opencontainers.image.source",
    "org.opencontainers.image.revision",
    "org.opencontainers.image.version",
    "io.infrashift.image.upstream.digest",
    "io.infrashift.image.upstream.source",
]

build_imgs = {k: v for k, v in V['images'].items() if v['kind'] == 'build'}

# --- Every declared Containerfile exists, and none is orphaned -------------
declared = {v['containerfile'] for v in build_imgs.values()}
on_disk = {os.path.join('Containerfiles', f) for f in os.listdir('Containerfiles')
           if f.endswith('.Containerfile')}
for p in sorted(declared - on_disk):
    err(p, "declared in versions.json but missing on disk")
for p in sorted(on_disk - declared):
    err(p, "exists on disk but no versions.json entry references it")

def instructions(text):
    """Logical Dockerfile instructions, with continuations joined."""
    out, buf = [], ""
    for raw in text.splitlines():
        line = raw.strip()
        if not line or line.startswith('#'):
            continue
        buf += line
        if line.endswith('\\'):
            buf = buf[:-1] + " "
            continue
        out.append(buf.strip())
        buf = ""
    if buf.strip():
        out.append(buf.strip())
    return out

for svc, img in sorted(build_imgs.items()):
    p = img['containerfile']
    if p not in on_disk:
        continue
    text = open(p).read()
    ins = instructions(text)
    # Comment-stripped view. Every content assertion below runs against this,
    # never against `text`: the comments in these files deliberately name the
    # flags and paths being asserted, so scanning raw text would let a check
    # pass on its own documentation.
    code = "\n".join(ins)
    heads = [i.split(None, 1)[0].upper() for i in ins]
    rt = img['runtime']
    b = img['build']

    # --- Pre-FROM global ARGs -------------------------------------------
    first_from = next((n for n, h in enumerate(heads) if h == 'FROM'), None)
    if first_from is None:
        err(p, "no FROM instruction"); continue
    pre = [i for i in ins[:first_from] if i.upper().startswith('ARG ')]
    pre_names = {i.split()[1] for i in pre}
    for need in ("UPSTREAM_BASE", "UPSTREAM_DIGEST", "CA_BASE", "CA_DIGEST",
                 "TOOLCHAIN_BASE", "TOOLCHAIN_DIGEST"):
        if need not in pre_names:
            err(p, f"missing pre-FROM `ARG {need}`")

    # --- ARGs re-declared after the LAST FROM ---------------------------
    # This is the real bug the reference repo had to fix: ARGs before the first
    # FROM are global build args and are NOT in scope inside a stage, so the
    # LABELs expand to empty strings and the policy denies with
    # BUILD_LABEL_EMPTY.
    last_from = max(n for n, h in enumerate(heads) if h == 'FROM')
    post = {i.split()[1] for i in ins[last_from:] if i.upper().startswith('ARG ')}
    for need in ("UPSTREAM_BASE", "UPSTREAM_DIGEST"):
        if need not in post:
            err(p, f"`ARG {need}` is not re-declared after the runtime FROM; "
                   f"the LABEL referencing it would expand to an empty string")

    # --- Exactly three stages, digest-pinned ----------------------------
    froms = [i for i in ins if i.upper().startswith('FROM ')]
    if len(froms) != 3:
        err(p, f"expected 3 stages (builder, certs, runtime), found {len(froms)}")
    for f in froms:
        if '@${' not in f:
            err(p, f"FROM is not digest-pinned via a build arg: {f!r}")
    if not any(f.upper().endswith(' AS BUILDER') for f in froms):
        err(p, "no `AS builder` stage")
    if not any(f.upper().endswith(' AS CERTS') for f in froms):
        err(p, "no `AS certs` stage (ubi9-micro ships no CA trust bundle)")

    # --- No hardcoded digests: versions.json is the only pin ------------
    for m in re.finditer(r'sha256:[a-f0-9]{7,}', code):
        err(p, f"hardcoded digest {m.group(0)[:20]}...; digests belong in versions.json only")

    # --- Exactly one LABEL block, carrying all five required labels -----
    labels = [i for i in ins if i.upper().startswith('LABEL ')]
    if len(labels) != 1:
        err(p, f"expected exactly 1 LABEL instruction, found {len(labels)}")
    else:
        for need in REQUIRED_LABELS:
            if need + '=' not in labels[0]:
                err(p, f"LABEL block is missing the policy-required `{need}`")

    # --- CA bundle really is copied and sanity-checked ------------------
    if 'tls-ca-bundle.pem' not in code:
        err(p, "does not copy a CA trust bundle; every service here makes outbound TLS calls "
               "and ubi9-micro ships none")
    if '-gt 100000' not in code:
        err(p, "does not assert the copied CA bundle is non-trivial (a truncated donor "
               "would ship an image that fails TLS only in production)")
    if '/usr/share/zoneinfo' not in code:
        err(p, "does not copy tzdata; ubi9-micro ships none and time.LoadLocation() "
               "would fail for anything but UTC")

    # --- Non-root, group 0, and USER 1001 LAST --------------------------
    if 'x:1001:0:' not in code:
        err(p, "does not append a UID 1001 / GID 0 passwd entry")
    if 'chmod -R g=u' not in code:
        err(p, "does not `chmod g=u`; the image would break under OpenShift's arbitrary-UID SCC")
    if not ins or ins[-1].upper() != 'USER 1001':
        err(p, f"last instruction must be `USER 1001`, found {ins[-1]!r}" if ins else "empty file")

    # --- Runtime declarations agree with versions.json ------------------
    exp = next((i for i in ins if i.upper().startswith('EXPOSE ')), None)
    got_ports = sorted(int(x) for x in exp.split()[1:]) if exp else []
    if got_ports != sorted(rt['ports']):
        err(p, f"EXPOSE {got_ports} disagrees with versions.json runtime.ports {sorted(rt['ports'])}")

    vols = sorted(v for i in ins if i.upper().startswith('VOLUME ') for v in i.split()[1:])
    if vols != sorted(rt.get('volumes', [])):
        err(p, f"VOLUME {vols} disagrees with versions.json runtime.volumes {sorted(rt.get('volumes', []))}")

    ep = next((i for i in ins if i.upper().startswith('ENTRYPOINT ')), None)
    if ep is None:
        err(p, "no ENTRYPOINT")
    else:
        try:
            got = json.loads(ep[len('ENTRYPOINT '):])
        except Exception:
            err(p, "ENTRYPOINT must be exec form (a JSON array); shell form loses PID-1 signal handling")
            got = None
        if got is not None and got != rt['entrypoint']:
            err(p, f"ENTRYPOINT {got} disagrees with versions.json runtime.entrypoint {rt['entrypoint']}")

    cmd = next((i for i in ins if i.upper().startswith('CMD ')), None)
    got_cmd = json.loads(cmd[len('CMD '):]) if cmd else []
    if got_cmd != rt.get('cmd', []):
        err(p, f"CMD {got_cmd} disagrees with versions.json runtime.cmd {rt.get('cmd', [])}")

    # --- Build recipe agrees with versions.json -------------------------
    if 'CGO_ENABLED=0' not in code:
        err(p, "does not set CGO_ENABLED=0; a glibc-2.41 binary from the Debian builder "
               "cannot run on ubi9's glibc 2.34")
    for sym in b['ldflagsVars'].values():
        if sym not in code:
            err(p, f"ldflags do not stamp `{sym}`; the binary would report `dev`")
    if b.get('trimpath') and '-trimpath' not in code:
        err(p, "versions.json declares trimpath but the build does not pass -trimpath")
    if b.get('goToolchain') and f"GOTOOLCHAIN={b['goToolchain']}" not in code:
        err(p, f"versions.json pins goToolchain {b['goToolchain']} but the build does not set it")
    if b.get('compatSymlink') and f"ln -sf {b['installPath']} {b['compatSymlink']}" not in code:
        err(p, f"versions.json declares compatSymlink {b['compatSymlink']} but it is not created")
    if f"-o /out/{b['binary']} {b['mainPackage']}" not in code:
        err(p, f"build does not produce /out/{b['binary']} from {b['mainPackage']}")
    if f"/out/{b['binary']} {b['installPath']}" not in code:
        err(p, f"binary is not installed to {b['installPath']}")

if fail:
    for m in fail:
        print(f"error: {m}", file=sys.stderr)
    print(f"\n{len(fail)} Containerfile issue(s)", file=sys.stderr)
    sys.exit(1)

print(f"OK: {len(build_imgs)} Containerfiles pass shape and versions.json agreement")
PY
