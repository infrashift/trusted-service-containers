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
package_imgs = {k: v for k, v in V['images'].items() if v['kind'] == 'package'}
native_imgs = {k: v for k, v in V['images'].items() if v['kind'] == 'native'}

# --- Every declared Containerfile exists, and none is orphaned -------------
declared = ({v['containerfile'] for v in build_imgs.values()} | {v['containerfile'] for v in package_imgs.values()}
            | {v['containerfile'] for v in native_imgs.values()})
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
    # `noVersionSymbol` says the program has no version variable. The Go
    # linker silently ignores -X for a symbol that does not exist, so any -X
    # here would be a stamp that never lands.
    if b.get('noVersionSymbol') and re.search(r'(^|\s)-X[\s=]', code):
        err(p, "versions.json declares noVersionSymbol, but the build passes -X; "
               "the linker ignores -X for a symbol that does not exist")
    if b.get('trimpath') and '-trimpath' not in code:
        err(p, "versions.json declares trimpath but the build does not pass -trimpath")
    if b.get('goToolchain') and f"GOTOOLCHAIN={b['goToolchain']}" not in code:
        err(p, f"versions.json pins goToolchain {b['goToolchain']} but the build does not set it")
    # A version-string GOTOOLCHAIN that differs from the toolchain image makes
    # `go` DOWNLOAD that compiler and build with it. nats carried go1.26.6 this
    # way; bumping the image to 1.26.9 for a Critical would have left nats on
    # 1.26.6 with every advisory intact, while the pin said otherwise.
    tc = V['toolchains'].get(img.get('toolchain'), {})
    gt = b.get('goToolchain', 'local')
    if gt != 'local' and gt != f"go{tc.get('goVersion')}":
        err(p, f"goToolchain {gt} is not the pinned toolchain's go{tc.get('goVersion')}; "
               f"`go` would download {gt} instead of using the image's compiler. Use `local`")
    for m in re.finditer(r'GOTOOLCHAIN=(\S+)', code):
        if m.group(1) not in ('local', f"go{tc.get('goVersion')}"):
            err(p, f"sets GOTOOLCHAIN={m.group(1)}, which is not the pinned toolchain's "
                   f"go{tc.get('goVersion')}; use `local`")
    if b.get('compatSymlink') and f"ln -sf {b['installPath']} {b['compatSymlink']}" not in code:
        err(p, f"versions.json declares compatSymlink {b['compatSymlink']} but it is not created")
    if f"-o /out/{b['binary']} {b['mainPackage']}" not in code:
        err(p, f"build does not produce /out/{b['binary']} from {b['mainPackage']}")
    if f"/out/{b['binary']} {b['installPath']}" not in code:
        err(p, f"binary is not installed to {b['installPath']}")
    if b.get('tags') and f"-tags={','.join(b['tags'])}" not in code:
        err(p, f"versions.json declares tags {b['tags']} but the build does not pass "
               f"-tags={','.join(b['tags'])}")
    for x in b.get('extraBinaries', []):
        if f"-o /out/{x['binary']} {x['mainPackage']}" not in code:
            err(p, f"extra binary /out/{x['binary']} is not built from {x['mainPackage']}")
        if f"/out/{x['binary']} {x['installPath']}" not in code:
            err(p, f"extra binary {x['binary']} is not installed to {x['installPath']}")

    # --- A first-party image claims no vendor comparison ----------------
    # versions.json `firstParty` (ADR-008) means no vendor binary exists.
    # build-leg.sh passes no CROSSCHECK_* build args for it, so a crosscheck
    # LABEL would expand to "@" -- an image label naming a comparison that
    # never ran. Checked against the comment-stripped code, never `text`.
    if 'firstParty' in img and 'CROSSCHECK_' in code:
        err(p, "versions.json declares firstParty (no vendor binary), but the Containerfile "
               "references CROSSCHECK_*; drop the crosscheck ARGs and label")

    # --- Declared release assets actually reach the builder -------------
    # scripts/fetch-assets.sh verifies them into src/.assets/<service>/. A
    # Containerfile that never copies them builds without them: for Prometheus
    # that is a binary with no UI, which still starts and still passes a
    # health check.
    if V['sources'].get(img['source'], {}).get('assets') and f"src/.assets/{svc}/" not in code:
        err(p, f"sources.{img['source']} declares assets but the build never copies src/.assets/{svc}/")

# ===========================================================================
# Package-track Containerfiles (ADR-009): signed RPMs at pinned NEVRAs on our
# base. No compiler, so none of the Go checks above apply; these do instead.
# ===========================================================================
def runtime_checks(p, ins, rt):
    exp = next((i for i in ins if i.upper().startswith('EXPOSE ')), None)
    got_ports = sorted(int(x) for x in exp.split()[1:]) if exp else []
    if got_ports != sorted(rt['ports']):
        err(p, f"EXPOSE {got_ports} disagrees with versions.json runtime.ports {sorted(rt['ports'])}")
    vols = sorted(v for i in ins if i.upper().startswith('VOLUME ') for v in i.split()[1:])
    if vols != sorted(rt.get('volumes', [])):
        err(p, f"VOLUME {vols} disagrees with versions.json runtime.volumes {sorted(rt.get('volumes', []))}")
    for kw, want in (('ENTRYPOINT', rt['entrypoint']), ('CMD', rt.get('cmd', []))):
        line = next((i for i in ins if i.upper().startswith(kw + ' ')), None)
        if line is None:
            if want:
                err(p, f"no {kw}")
            continue
        try:
            got = json.loads(line[len(kw) + 1:])
        except Exception:
            err(p, f"{kw} must be exec form (a JSON array)")
            continue
        if got != want:
            err(p, f"{kw} {got} disagrees with versions.json runtime.{kw.lower()} {want}")

for svc, img in sorted(package_imgs.items()):
    p = img['containerfile']
    if p not in on_disk:
        continue
    ins = instructions(open(p).read())
    code = "\n".join(ins)
    heads = [i.split(None, 1)[0].upper() for i in ins]
    rt = img['runtime']

    froms = [i for i in ins if i.upper().startswith('FROM ')]
    if len(froms) != 1:
        err(p, f"a package image has exactly 1 stage, on the pinned base; found {len(froms)}")
    for f in froms:
        if f != 'FROM ${UPSTREAM_BASE}@${UPSTREAM_DIGEST}':
            err(p, f"FROM must be the pinned base via build args, `FROM ${{UPSTREAM_BASE}}@${{UPSTREAM_DIGEST}}`: {f!r}")
    if not froms:
        continue
    first_from = heads.index('FROM')
    pre = {i.split()[1] for i in ins[:first_from] if i.upper().startswith('ARG ')}
    post = {i.split()[1] for i in ins[first_from:] if i.upper().startswith('ARG ')}
    for need in ("UPSTREAM_BASE", "UPSTREAM_DIGEST"):
        if need not in pre:
            err(p, f"missing pre-FROM `ARG {need}`")
    for need in ("UPSTREAM_BASE", "UPSTREAM_DIGEST", "PACKAGE_REPO_ID", "PACKAGE_BASEURL", "PACKAGE_KEY",
                 "PACKAGE_KEY_SHA256", "PACKAGE_KEY_ID", "PACKAGE_NEVRAS", "PACKAGE_VERSION", "PACKAGE_EVR"):
        if need not in post:
            err(p, f"`ARG {need}` is not declared after FROM; anything that references it expands to an empty string")

    for m in re.finditer(r'sha256:[a-f0-9]{7,}', code):
        err(p, f"hardcoded digest {m.group(0)[:20]}...; digests belong in versions.json only")

    # The five labels, each from the build arg the policy holds it against:
    # PACKAGE_SOURCE/REVISION/VERSION_LABEL_DISAGREES and BUILD_LABEL_DIGEST_DISAGREES.
    labels = [i for i in ins if i.upper().startswith('LABEL ')]
    if len(labels) != 1:
        err(p, f"expected exactly 1 LABEL instruction, found {len(labels)}")
    else:
        for name, arg in (("org.opencontainers.image.source", "PACKAGE_BASEURL"),
                          ("org.opencontainers.image.revision", "PACKAGE_EVR"),
                          ("org.opencontainers.image.version", "PACKAGE_VERSION"),
                          ("io.infrashift.image.upstream.digest", "UPSTREAM_DIGEST"),
                          ("io.infrashift.image.upstream.source", "UPSTREAM_BASE")):
            if f'{name}="${{{arg}}}"' not in labels[0]:
                err(p, f'LABEL block must set {name}="${{{arg}}}"')

    # Signature checking is never turned off, by any spelling.
    for bad in (r'--nogpgcheck', r'gpgcheck\s*=\s*0', r'--setopt=\S*gpgcheck=(0|False|false)', r'--no-gpg', r'rpm\s+(-i|-U|--install|--upgrade)\b.*--nosignature'):
        if re.search(bad, code):
            err(p, f"disables signature checking ({bad}); every RPM and the repository metadata must verify")
    if not re.search(r'\\ngpgcheck=1\\n', code) or not re.search(r'\\nrepo_gpgcheck=1\\n', code):
        err(p, "the repository file must set gpgcheck=1 and repo_gpgcheck=1")
    if 'gpgkey=file://' not in code:
        err(p, "the repository file must name the committed key (gpgkey=file://...)")
    if 'sha256sum --check --strict' not in code or '${PACKAGE_KEY_SHA256}' not in code:
        err(p, "the key file is not checked against PACKAGE_KEY_SHA256 before it is imported")
    if not re.search(r'COPY \$\{PACKAGE_KEY\} /etc/pki/rpm-gpg/RPM-GPG-KEY-\$\{PACKAGE_REPO_ID\}', code):
        err(p, "the committed key must be copied to /etc/pki/rpm-gpg/RPM-GPG-KEY-${PACKAGE_REPO_ID}; scripts/package-observe.sh reads it there")
    if '/etc/yum.repos.d/tsc-${PACKAGE_REPO_ID}.repo' not in code:
        err(p, "the repository file must be /etc/yum.repos.d/tsc-${PACKAGE_REPO_ID}.repo; scripts/package-observe.sh reads it there")
    inst = re.search(r'\b(microdnf|dnf)\b[^;]*\binstall\b[^;]*\$\{PACKAGE_NEVRAS\}', code)
    if not inst:
        err(p, "does not install exactly ${PACKAGE_NEVRAS}; a package name alone is not a pin")
    imp = code.find('rpm --import')
    upg = re.search(r'\bmicrodnf\b[^;]*\bupgrade\b', code)
    if imp < 0:
        err(p, "does not `rpm --import` the pinned key")
    elif upg is None or upg.start() > imp:
        err(p, "must upgrade the base from the UBI repositories BEFORE the third-party key and repository exist, so no third-party package can replace a base package")
    if "rpm -q --qf '%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}\\n' \"$nevra\"" not in code:
        err(p, "does not verify every pinned NEVRA with `rpm -q` after the install")
    if 'Key ID ${PACKAGE_KEY_ID}' not in code:
        err(p, "does not check that each pinned NEVRA is signed by ${PACKAGE_KEY_ID}")

    # Non-root, group 0, no root at runtime.
    if 'chmod -R g=u' not in code:
        err(p, "does not `chmod g=u`; the image would break under OpenShift's arbitrary-UID SCC")
    if not re.search(r'usermod -g 0\b', code):
        err(p, "the runtime user's primary group must be GID 0 (usermod -g 0)")
    want_user = f"USER {rt['user']}"
    if not ins or ins[-1].upper() != want_user:
        err(p, f"last instruction must be `{want_user}`, found {ins[-1]!r}" if ins else "empty file")
    if f"COPY rootfs/{svc}/ /" not in code:
        err(p, f"does not copy rootfs/{svc}/")
    runtime_checks(p, ins, rt)

# ===========================================================================
# Native Containerfiles (ADR-010): compile a pinned source commit on a pinned
# UBI builder, with the compiler from the signed UBI repositories, onto our
# base. Two stages, `AS builder` and the runtime.
# ===========================================================================
SIG_BYPASS = (r'--nogpgcheck', r'gpgcheck\s*=\s*0', r'--setopt=\S*gpgcheck=(0|False|false)', r'--no-gpg',
              r'rpm\s+(-i|-U|--install|--upgrade)\b.*--nosignature')

for svc, img in sorted(native_imgs.items()):
    p = img['containerfile']
    if p not in on_disk:
        continue
    ins = instructions(open(p).read())
    code = "\n".join(ins)
    heads = [i.split(None, 1)[0].upper() for i in ins]
    rt = img['runtime']
    nat = img.get('native', {})

    froms = [i for i in ins if i.upper().startswith('FROM ')]
    want_froms = ['FROM ${BUILDER_BASE}@${BUILDER_DIGEST} AS builder', 'FROM ${UPSTREAM_BASE}@${UPSTREAM_DIGEST}']
    if froms != want_froms:
        err(p, f"a native image has exactly 2 stages, the pinned UBI builder then the pinned runtime base: {want_froms}; found {froms}")
    if 'FROM' not in heads:
        continue
    first_from = heads.index('FROM')
    last_from = max(n for n, h in enumerate(heads) if h == 'FROM')
    pre = {i.split()[1] for i in ins[:first_from] if i.upper().startswith('ARG ')}
    post = {i.split()[1] for i in ins[last_from:] if i.upper().startswith('ARG ')}
    for need in ("BUILDER_BASE", "BUILDER_DIGEST", "UPSTREAM_BASE", "UPSTREAM_DIGEST"):
        if need not in pre:
            err(p, f"missing pre-FROM `ARG {need}`")
    for need in ("UPSTREAM_BASE", "UPSTREAM_DIGEST", "SOURCE_URL", "SOURCE_REF", "SOURCE_VERSION"):
        if need not in post:
            err(p, f"`ARG {need}` is not declared after the runtime FROM; the LABEL referencing it would expand to an empty string")

    for m in re.finditer(r'sha256:[a-f0-9]{7,}', code):
        err(p, f"hardcoded digest {m.group(0)[:20]}...; digests belong in versions.json only")

    # The five labels, each from the build arg the policy holds it against:
    # NATIVE_SOURCE_LABEL_DISAGREES, BUILD_REVISION_LABEL_DISAGREES,
    # NATIVE_VERSION_LABEL_DISAGREES and BUILD_LABEL_DIGEST_DISAGREES.
    labels = [i for i in ins[last_from:] if i.upper().startswith('LABEL ')]
    if len(labels) != 1 or len([i for i in ins if i.upper().startswith('LABEL ')]) != 1:
        err(p, "expected exactly 1 LABEL instruction, in the runtime stage")
    else:
        for name, arg in (("org.opencontainers.image.source", "SOURCE_URL"),
                          ("org.opencontainers.image.revision", "SOURCE_REF"),
                          ("org.opencontainers.image.version", "SOURCE_VERSION"),
                          ("io.infrashift.image.upstream.digest", "UPSTREAM_DIGEST"),
                          ("io.infrashift.image.upstream.source", "UPSTREAM_BASE")):
            if f'{name}="${{{arg}}}"' not in labels[0]:
                err(p, f'LABEL block must set {name}="${{{arg}}}"')

    # Signed UBI packages only: no way to turn a signature check off, and no
    # third-party repository or key.
    for bad in SIG_BYPASS:
        if re.search(bad, code):
            err(p, f"disables signature checking ({bad}); every RPM must verify against the Red Hat key")
    for bad in (r'/etc/yum\.repos\.d', r'\bbaseurl=', r'rpm\s+--import', r'--repofrompath', r'--enablerepo'):
        if re.search(bad, code):
            err(p, f"adds or enables a repository ({bad}); a native build uses only the signed UBI repositories of its base")

    builder = "\n".join(ins[first_from:last_from])
    runtime = "\n".join(ins[last_from:])
    if not re.search(r'\bmicrodnf\b[^;]*\binstall\b[^;]*\$\{BUILD_PACKAGES\}', builder):
        err(p, "the builder does not install exactly ${BUILD_PACKAGES} (versions.json native.buildPackages)")
    if 'ARG BUILD_PACKAGES' not in builder:
        err(p, "the builder stage does not declare `ARG BUILD_PACKAGES`")
    if not re.search(r'\bmicrodnf\b[^;]*\bupgrade\b', runtime):
        err(p, "the runtime stage does not upgrade its base from the signed UBI repositories")
    if '${BUILD_PACKAGES}' in runtime or re.search(r'\binstall\b[^;]*\b(gcc|gcc-c\+\+|make|binutils|[A-Za-z0-9_.+-]+-devel)\b', runtime):
        err(p, "the runtime stage installs a compiler or a -devel package; they belong in the builder only")

    if nat.get('language') == 'c':
        if f"COPY src/{svc}/ " not in builder:
            err(p, f"the builder does not copy the pinned source checkout src/{svc}/")
        # Every make command, split at ; && ||, so a flag on `make install`
        # alone cannot stand in for the compile.
        make = [m for m in re.findall(r'(?:^|[;&|]\s*)(make\b[^;&|]*)', builder, re.M)]
        if not make:
            err(p, "the builder runs no make command")
        for flag in nat.get('makeFlags', []):
            for m in make:
                if not re.search(r'(^|\s)' + re.escape(flag) + r'(\s|$)', m):
                    err(p, f"versions.json native.makeFlags declares {flag}, but `{m.strip()[:60]}` does not pass it")
        for path in [nat.get('installPath')] + nat.get('extraBinaries', []):
            if path and f"COPY --from=builder /out{path} {path}" not in runtime:
                err(p, f"the runtime stage does not install {path} from the builder (COPY --from=builder /out{path} {path})")

    if nat.get('language') == 'python':
        lock = nat.get('lock', {}).get('path', '')
        venv = nat.get('venv', '')
        for need in ('LOCK_SHA256', 'VENV'):
            if f'ARG {need}' not in builder:
                err(p, f"the builder stage does not declare `ARG {need}`")
        if f"COPY {lock} /tmp/requirements.txt" not in builder:
            err(p, f"the builder does not copy the pinned lock {lock} to /tmp/requirements.txt")
        if not re.search(r'\$\{LOCK_SHA256\}[^;]*/tmp/requirements\.txt[^;]*\|\s*sha256sum --check --strict', builder):
            err(p, "the lock is not checked against ${LOCK_SHA256} with `sha256sum --check --strict` in the builder")
        if not re.search(r'-m venv --without-pip "?\$\{VENV\}"?', builder):
            err(p, "the venv is not created with `-m venv --without-pip ${VENV}`; pip in the venv would be an unlocked distribution")
        pip = re.findall(r'-m pip\b[^;&|]*\binstall\b[^;&|]*', builder)
        if len(pip) != 1:
            err(p, f"the builder must run exactly one `pip install`, found {len(pip)}")
        for cmd in pip:
            for flag in ('--require-hashes', '--no-deps', '--only-binary=:all:', '-r /tmp/requirements.txt'):
                if flag not in cmd:
                    err(p, f"`pip install` does not pass {flag}; the lock would not bind what pip installs")
        pipcmds = re.findall(r'\bpip\b[^;&|]*', code)
        for bad in (r'--trusted-host', r'--extra-index-url', r'--index-url\s+http://', r'--no-binary', r'--find-links', r'(^|\s)-f\s'):
            if any(re.search(bad, c) for c in pipcmds):
                err(p, f"the pip invocation uses {bad}; only hash-checked wheels from the default index are allowed")
        if not re.search(r'-m pip(\s+--python\s+\S+)?\s+check\s*(;|$)', builder, re.M):
            err(p, "the builder does not run `pip check` on the venv")
        if not re.search(r'/tmp/requirements\.txt "?\$\{VENV\}/requirements\.txt"?', builder):
            err(p, "the lock is not installed at ${VENV}/requirements.txt; scripts/native-python-observe.sh reads it there")
        if not re.search(r'\bmicrodnf\b[^;]*\binstall\b[^;]*\$\{RUNTIME_PACKAGES\}', runtime):
            err(p, "the runtime stage does not install exactly ${RUNTIME_PACKAGES} (versions.json native.runtimePackages)")
        if re.search(r'\bpip\b[^;]*\binstall\b', runtime):
            err(p, "the runtime stage runs pip; the venv comes from the builder only")
        if venv and f"COPY --from=builder {venv} {venv}" not in runtime:
            err(p, f"the runtime stage does not copy the venv {venv} from the builder")

    # Non-root, group 0, and USER 1001 last.
    if 'x:1001:0:' not in runtime:
        err(p, "does not append a UID 1001 / GID 0 passwd entry")
    if 'chmod -R g=u' not in runtime:
        err(p, "does not `chmod g=u`; the image would break under OpenShift's arbitrary-UID SCC")
    if not ins or ins[-1].upper() != 'USER 1001':
        err(p, f"last instruction must be `USER 1001`, found {ins[-1]!r}" if ins else "empty file")
    if os.path.isdir(f"rootfs/{svc}") and f"COPY rootfs/{svc}/ /" not in runtime:
        err(p, f"rootfs/{svc}/ exists but the runtime stage does not copy it")
    cf = rt.get('configFile')
    if cf and not os.path.isfile(cf):
        err(p, f"versions.json runtime.configFile {cf} does not exist")
    if cf and not cf.startswith(f"rootfs/{svc}/"):
        err(p, f"versions.json runtime.configFile {cf} is not under rootfs/{svc}/")
    runtime_checks(p, ins, rt)

if fail:
    for m in fail:
        print(f"error: {m}", file=sys.stderr)
    print(f"\n{len(fail)} Containerfile issue(s)", file=sys.stderr)
    sys.exit(1)

print(f"OK: {len(build_imgs) + len(package_imgs) + len(native_imgs)} Containerfiles ({len(build_imgs)} build, "
      f"{len(package_imgs)} package, {len(native_imgs)} native) pass shape and versions.json agreement")
PY
