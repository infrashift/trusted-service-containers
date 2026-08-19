# Ops.mk -- operational targets for trusted-service-containers.
#
# Usage:
#   make -f Ops.mk help
#   make -f Ops.mk validate
#   make -f Ops.mk verify-pins
#   make -f Ops.mk list-images target_namespace=development
#   make -f Ops.mk clean-ghcr-namespace target_namespace=development
#
# Two bugs from the reference repo's Ops.mk are deliberately fixed here:
#   1. Its `ifndef target_namespace / $(error ...)` sat at makefile top level,
#      so the error fired at PARSE time for every invocation -- including
#      `make -f Ops.mk help` and `make -f Ops.mk` with no target at all. The
#      guard here lives inside the recipe, where it belongs.
#   2. Its REPO/PKG_PREFIX were hardcoded to a stale repo name that disagreed
#      with the actual repository. Here they are derived from git.

SHELL := /bin/bash
.ONESHELL:
.SHELLFLAGS := -eu -o pipefail -c
.SILENT:

VERSIONS   := versions.json
POLICY_DIR := .github/pdp
OPA        ?= opa
GITLEAKS   ?= gitleaks

ORG        := infrashift
# basename then strip a trailing .git. The previous one-liner relied on a lazy
# quantifier that POSIX ERE does not have, so it left ".git" attached and every
# derived GHCR path was wrong -- invisible until a remote actually existed.
REPO_NAME  := $(shell git remote get-url origin 2>/dev/null | xargs -r basename | sed 's/\.git$$//')
REPO_NAME  := $(if $(REPO_NAME),$(REPO_NAME),trusted-service-containers)
PKG_PREFIX := $(REPO_NAME)
REGISTRY   := ghcr.io/$(ORG)/$(REPO_NAME)

# One package per service, both tracks. Mirror services publish their variants
# as tags on one package, so the package list is just the image keys.
IMAGES        := $(shell jq -r '.images | keys[]' $(VERSIONS) 2>/dev/null)
MIRROR_IMAGES := $(shell jq -r '[.images | to_entries[] | select(.value.kind=="mirror") | .key] | .[]' $(VERSIONS) 2>/dev/null)
BUILD_IMAGES  := $(shell jq -r '[.images | to_entries[] | select(.value.kind=="build")  | .key] | .[]' $(VERSIONS) 2>/dev/null)

define guard_namespace
	if [ -z "$(target_namespace)" ]; then
		echo "error: target_namespace is required (e.g. target_namespace=development)" >&2
		exit 2
	fi
	case "$(target_namespace)" in
		development|trusted|quarantine) : ;;
		*) echo "error: target_namespace must be development, trusted or quarantine" >&2; exit 2 ;;
	esac
endef

.PHONY: help
help:
	echo "trusted-service-containers -- Ops.mk"
	echo
	echo "  validate              schema + gitleaks + rego + workflow/shell lint + policy tests"
	echo "  lint-workflows        cross-workflow drift checks (guard, context, paths, perms)"
	echo "  lint-containerfiles   Containerfile shape + versions.json agreement"
	echo "  lint-skills           every documented file path resolves"
	echo "  policy-test           opa check --strict, opa fmt, opa test --threshold 85"
	echo "  repo-gate             evaluate data.tsc.pdp.repo_decision against this tree"
	echo "  verify-pins           re-resolve every upstream, base and crosscheck digest"
	echo "  verify-mirror-pins    mirror-track pins only"
	echo "  verify-build-pins     build-track base + crosscheck pins only"
	echo "  list-images           target_namespace=development|trusted|quarantine"
	echo "  clean-ghcr-namespace  target_namespace=development  (refuses trusted/)"
	echo
	echo "  registry: $(REGISTRY)"
	echo "  images:   $(words $(IMAGES)) ($(words $(MIRROR_IMAGES)) mirror, $(words $(BUILD_IMAGES)) build)"

.PHONY: validate
validate: check-versions check-schema check-gitleaks-config check-no-orphan-rego lint-workflows lint-containerfiles lint-skills lint-shell policy-test
	echo "OK: repository validation passed"

.PHONY: check-versions
check-versions:
	jq -e . $(VERSIONS) >/dev/null || { echo "error: $(VERSIONS) is not valid JSON" >&2; exit 1; }
	# Every digest field must be a real sha256. Placeholders (all zeros) are
	# structurally valid on purpose -- they are caught at mirror time by
	# PIN_MISMATCH against the live registry -- but a malformed one fails here.
	bad=$$(jq -r '[.. | objects | select(has("digest")) | .digest] | map(select(test("^sha256:[a-f0-9]{64}$$") | not)) | .[]' $(VERSIONS))
	if [ -n "$$bad" ]; then echo "error: malformed digest(s):" >&2; echo "$$bad" >&2; exit 1; fi
	# Warn loudly about unresolved placeholders so they cannot ship silently.
	ph=$$(jq -r '[.images | to_entries[] | .key as $$k | (.value.variants // {}) | to_entries[] | select(.value.digest == "sha256:0000000000000000000000000000000000000000000000000000000000000000") | $$k + "/" + .key] | .[]' $(VERSIONS))
	if [ -n "$$ph" ]; then
		echo "warning: unresolved digest placeholders (need an authenticated dhi.io login; see SETUP-ENVIRONMENTS.md):" >&2
		echo "$$ph" | sed 's/^/  /' >&2
	fi
	# A pinned shortCommit that is not a prefix of its commit would silently
	# stamp a wrong string into the binary and break the cross-check.
	jq -r '.sources | to_entries[] | select(.value.shortCommit) | [.key, .value.commit, .value.shortCommit] | @tsv' $(VERSIONS) \
	| while IFS=$$'\t' read -r k c sc; do
		case "$$c" in "$$sc"*) : ;; *) echo "error: sources.$$k.shortCommit '$$sc' is not a prefix of commit '$$c'" >&2; exit 1 ;; esac
	done
	echo "OK: $(VERSIONS)"

.PHONY: check-schema
check-schema:
	python3 scripts/validate-schema.py

.PHONY: check-gitleaks-config
check-gitleaks-config:
	# The reference shipped a 0-byte .gitleaks.toml. gitleaks reads an empty
	# config as ZERO RULES, scans nothing, and exits 0 -- indistinguishable
	# from a clean scan. This is guard #2 of three; the third is in the policy.
	bytes=$$(stat -c%s .gitleaks.toml)
	if [ "$$bytes" -lt 64 ]; then echo "error: .gitleaks.toml is $$bytes bytes -- an empty config disables every rule" >&2; exit 1; fi
	grep -qE 'useDefault[[:space:]]*=[[:space:]]*true' .gitleaks.toml || { echo "error: .gitleaks.toml must extend the default ruleset" >&2; exit 1; }
	echo "OK: .gitleaks.toml ($$bytes bytes, extends defaults)"

.PHONY: check-no-orphan-rego
check-no-orphan-rego:
	./scripts/check-no-orphan-rego.sh

.PHONY: lint-workflows
lint-workflows:
	./scripts/lint-workflows.sh

.PHONY: lint-containerfiles
lint-containerfiles:
	./scripts/lint-containerfiles.sh

.PHONY: lint-skills
lint-skills:
	./scripts/lint-skills.sh

.PHONY: lint-shell
lint-shell:
	if command -v shellcheck >/dev/null 2>&1; then
		shellcheck -S warning scripts/*.sh
		echo "OK: shellcheck clean"
	else
		echo "warning: shellcheck not installed; skipping shell lint" >&2
	fi

.PHONY: policy-test
policy-test:
	$(OPA) check --strict $(POLICY_DIR)/
	out=$$($(OPA) fmt --list $(POLICY_DIR)/); if [ -n "$$out" ]; then echo "error: rego needs formatting:" >&2; echo "$$out" >&2; exit 1; fi
	$(OPA) test $(POLICY_DIR)/ | tail -1
	# --threshold prints the full coverage document on stdout; keep the summary,
	# drop the 300KB of line ranges.
	cov=$$($(OPA) test $(POLICY_DIR)/ --coverage --format json | jq -r '.coverage')
	printf 'coverage: %.1f%%\n' "$$cov"
	awk -v c="$$cov" 'BEGIN{ if (c+0 < 85) { print "error: coverage " c "% is below the 85% threshold" > "/dev/stderr"; exit 1 } }'

.PHONY: repo-gate
repo-gate:
	./scripts/repo-gate.sh

.PHONY: verify-pins
verify-pins: verify-mirror-pins verify-build-pins

.PHONY: verify-mirror-pins
verify-mirror-pins:
	echo "Re-resolving mirrored upstream tags..."
	stale=0
	while IFS=$$'\t' read -r key variant repo tag track pinned; do
		if [ "$$pinned" = "sha256:0000000000000000000000000000000000000000000000000000000000000000" ]; then
			printf '  %-16s %-8s PLACEHOLDER  (needs authenticated resolve)\n' "$$key" "$$variant"
			continue
		fi
		actual=$$(regctl manifest head --format '{{.GetDescriptor.Digest}}' "$$repo:$$tag" 2>/dev/null || echo '<unresolvable>')
		if [ "$$actual" = "$$pinned" ]; then
			printf '  %-16s %-8s current\n' "$$key" "$$variant"
		else
			printf '  %-16s %-8s STALE  pinned=%s actual=%s\n' "$$key" "$$variant" "$$pinned" "$$actual"
			stale=$$((stale + 1))
		fi
		# A track constraint means the TAG may also need to advance, not just the
		# digest behind it. Widening the track is a policy change, not a bump.
		printf '      track %s\n' "$$track"
	done < <(jq -r '.images | to_entries[] | select(.value.kind=="mirror") | .key as $$k | .value.upstreamRepo as $$r | .value.variants | to_entries[] | [$$k, .key, $$r, .value.tag, .value.track, .value.digest] | @tsv' $(VERSIONS))
	if [ "$$stale" -ne 0 ]; then echo "$$stale mirror pin(s) stale." >&2; exit 1; fi

.PHONY: verify-build-pins
verify-build-pins:
	echo "Checking build-track base images and crosscheck references..."
	stale=0
	while IFS=$$'\t' read -r key base_repo base_digest arch; do
		actual=$$(regctl manifest head --platform "linux/$$arch" --format '{{.GetDescriptor.Digest}}' "$$base_repo:latest" 2>/dev/null || echo '<unresolvable>')
		if [ "$$actual" = "$$base_digest" ]; then
			printf '  %-16s base %-6s current\n' "$$key" "$$arch"
		else
			printf '  %-16s base %-6s STALE  pinned=%s latest=%s\n' "$$key" "$$arch" "$$base_digest" "$$actual"
			stale=$$((stale + 1))
		fi
	done < <(jq -r '. as $$d | $$d.images | to_entries[] | select(.value.kind=="build") | .key as $$k | .value.base as $$b | .value.arches[] as $$a | [$$k, $$d.bases[$$b].image, $$d.bases[$$b][$$a].digest, $$a] | @tsv' $(VERSIONS))
	echo "Source pins:"
	jq -r '.sources | to_entries[] | .key as $$s | (if (.value.repos // empty) then (.value.repos | to_entries[] | "  \($$s)/\(.key)  \(.value.commit[0:12])") else "  \($$s)  \(.value.commit[0:12])" end)' $(VERSIONS)
	echo "Crosscheck pins:"
	jq -r '.images | to_entries[] | select(.value.kind=="build") | .key as $$k | .value.crosscheck as $$c | $$c.arches // ["amd64","arm64"] | .[] as $$a | "  \($$k) \($$a)  \($$c[$$a].tag // "-")"' $(VERSIONS) 2>/dev/null || true
	if [ "$$stale" -ne 0 ]; then echo "$$stale base pin(s) stale." >&2; exit 1; fi

.PHONY: list-images
list-images:
	$(guard_namespace)
	echo "=== $(REGISTRY)/$(target_namespace) ==="
	for img in $(IMAGES); do
		pkg="$(PKG_PREFIX)%2F$(target_namespace)%2F$${img}"
		tags=$$(gh api "orgs/$(ORG)/packages/container/$${pkg}/versions" \
			--jq '[.[].metadata.container.tags[] | select(startswith("sha256-") | not)] | sort | join(", ")' 2>/dev/null || true)
		if [ -n "$$tags" ]; then printf '  %-18s %s\n' "$$img" "$$tags"; else printf '  %-18s (none)\n' "$$img"; fi
	done

.PHONY: clean-ghcr-namespace
clean-ghcr-namespace:
	$(guard_namespace)
	# Refuse to bulk-delete promoted images. Quarantine is also protected: it is
	# a documented state carrying signed evidence, not a wastebasket.
	if [ "$(target_namespace)" != "development" ]; then
		echo "error: clean-ghcr-namespace only operates on 'development'." >&2
		echo "       trusted/ and quarantine/ hold signed, referenced artifacts." >&2
		exit 2
	fi
	echo "Cleaning $(REGISTRY)/$(target_namespace)..."
	for img in $(IMAGES); do
		pkg="$(PKG_PREFIX)%2F$(target_namespace)%2F$${img}"
		if gh api "orgs/$(ORG)/packages/container/$${pkg}" --jq '.name' >/dev/null 2>&1; then
			printf '  deleting %s... ' "$(target_namespace)/$${img}"
			gh api -X DELETE "orgs/$(ORG)/packages/container/$${pkg}" >/dev/null 2>&1 && echo done || echo failed
		fi
	done

.PHONY: show-config
show-config:
	echo "ORG        = $(ORG)"
	echo "REPO_NAME  = $(REPO_NAME)"
	echo "REGISTRY   = $(REGISTRY)"
	echo "IMAGES     = $(IMAGES)"
	echo "MIRROR     = $(MIRROR_IMAGES)"
	echo "BUILD      = $(BUILD_IMAGES)"
