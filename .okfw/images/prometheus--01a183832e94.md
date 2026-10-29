---
id: "01a18383-2e94-74bc-8d71-5daf1548d972"
title: "prometheus"
type: "image"
tags:
  - "image"
  - "prometheus"
  - "build"
created: "2026-10-28T12:16:14-05:00"
timestamp: "2026-10-28T12:23:41-05:00"
description: "The Prometheus monitoring server with promtool and the prebuilt web UI of the vendor, built from source onto ubi9-micro."
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:23:41-05:00"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/versions.json"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/Containerfiles/prometheus.Containerfile"
    title: "prometheus.Containerfile"
x:
  github: 25
---

# prometheus

prometheus is the Prometheus monitoring server, with `promtool`. We build it from source onto `ubi9-micro`.

## Track

Build track. We compile `prometheus` and `promtool` from the pinned `sources.prometheus` commit with `Containerfiles/prometheus.Containerfile`. The source track is the 3.15 minor line. See [Build track](/architecture/build-track--01a18382f2d2.md).

No usable UBI-based Prometheus exists. The Red Hat image needs an entitled, authenticated pull. It contains the OpenShift fork on the OpenShift release train. The DHI image uses Debian.

## Trust class

`internal`. We verify our `ubi9-micro` base against the release key of `infrashift/trusted-base-images`. See [Upstream trust classes](/architecture/upstream-trust-classes--01a18382f3fb.md).

The binary cross-check compares our binary with the binary in `quay.io/prometheus/prometheus`, trust class `none` (the vendor image is unsigned), tier `best-effort`. The upstream compiles with Go 1.27, and we use the go1.26 toolchain. Thus a mismatch is expected and proves nothing. See [ADR-004: Dual provenance is an observation, not a gate](/decisions/adr-004-dual-provenance-is-an-observation-not-a-gate--01a18382f4a6.md).

## Enforcement

See `versions.json` for the current value. On 2026-10-28 the value was `enforce`.

The image joined in `observe` mode. It moved to `enforce` on 2026-10-01. Before the move, its first review (PR #25) was clean on both architectures. It had zero blocking findings, zero waivers and six recorded findings that do not block.

## Variants and platforms

One variant, `runtime`. Architectures: `amd64`, `arm64`. The upstream index also has arm/v7, ppc64le, riscv64 and s390x. We do not build them.

## Runtime

* Port: 9090.
* Volume: /prometheus, the TSDB. Without a persistent mount, each restart loses all history. Nothing shows the loss.
* Command: `prometheus` with the upstream example configuration and `--storage.tsdb.path=/prometheus`. Like the vendor image, the image can run alone. A real deployment mounts its own configuration and a web configuration for TLS.
* User: 1001.

## Notes

* The build tags (`netgo`, `builtinassets`) and the ldflags come from the upstream `.promu.yml`. The version is the ref without its leading `v`. The build date is the source commit date, not the clock. Thus a rerun stamps the same string.
* A source build without Node has no web UI. The image embeds the prebuilt web UI tarball of the vendor. `scripts/fetch-assets.sh` fetches the tarball and verifies the sha256 in `versions.json`. It refuses a URL that does not name the release that it builds. Prometheus does not sign release assets, so this hash is the trust claim. A drift bump moves the URL but cannot re-pin the hash.
* The Containerfile checks the generated asset file. Without this file, `builtinassets` still compiles and the binary starts. Only a person who opens the browser sees that the UI is missing.
* `-s -w` is our flag, not an upstream flag. It removes only the symbol and DWARF tables. The Go build info that scanners and `go version -m` read stays in the binary.
* The image contains `promtool` on purpose. It is the only HTTP client in the image, because `ubi9-micro` has no `curl`. Consumers use `promtool check healthy --http.config.file` as a health check that can present a client certificate.
* Consumer: `infrashift/ansible-collection-infrashift-hashistack`, terraform/live/prometheus.

## Issues and waivers

Open issues:

* [The notes in versions.json are stale](/issues/the-notes-in-versions-json-are-stale--01a18395b56b.md)

Resolved issues:

* [The go1.26 toolchain pin 1.26.6 put 8 stdlib findings into every Go build](/issues/the-go1-26-toolchain-pin-1-26-6-put-8-stdlib-findings-into-every-go-build--01a1838a13e9.md)
* [The ubi9-minimal base pins were behind the sibling repository on 2026-10-28](/issues/the-ubi9-minimal-base-pins-were-behind-the-sibling-repository-on-2026-10-28--01a1838a1487.md)
* [The ubi9-micro base pins were behind the sibling repository on 2026-10-14](/issues/the-ubi9-micro-base-pins-were-behind-the-sibling-repository-on-2026-10-14--01a1838a1439.md)

Measurements:

* [On 2026-10-28 every build leg was trusted and every mirror leg was quarantined](/findings/on-2026-10-28-every-build-leg-was-trusted-and-every-mirror-leg-was-quarantined--01a1838a6fc5.md)

## Related

* [loki](/images/loki--01a183832eba.md)
* [prometheus-nats-exporter](/images/prometheus-nats-exporter--01a183832f0f.md)
* [Build track](/architecture/build-track--01a18382f2d2.md)
* [ADR-001: Observe enforcement mode](/decisions/adr-001-observe-enforcement-mode--01a18382f44e.md)
* [Images overview](/images/images-overview--01a1837da526.md)
* [Move an image from observe to enforce](/operations/move-an-image-from-observe-to-enforce--01a18383dac5.md)
* [Bump an upstream source within its track](/operations/bump-an-upstream-source-within-its-track--01a18383da54.md)
