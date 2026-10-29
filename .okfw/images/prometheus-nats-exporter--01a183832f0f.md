---
id: "01a18383-2f0f-7167-8f56-02f42d49cf06"
title: "prometheus-nats-exporter"
type: "image"
tags:
  - "image"
  - "prometheus-nats-exporter"
  - "build"
created: "2026-10-28T12:16:14-05:00"
timestamp: "2026-10-28T12:23:41-05:00"
description: "The Prometheus exporter for NATS monitoring endpoints, built from source onto ubi9-micro; PR #29 is the reason for the observe-is-not-a-pass rule."
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:23:41-05:00"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/versions.json"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/Containerfiles/prometheus-nats-exporter.Containerfile"
    title: "prometheus-nats-exporter.Containerfile"
  - resource: "https://github.com/infrashift/trusted-service-containers/pull/29"
    title: "PR #29"
x:
  github: 29
---

# prometheus-nats-exporter

prometheus-nats-exporter is the Prometheus exporter for the NATS server and JetStream monitoring endpoints. We build it from source onto `ubi9-micro`.

## Track

Build track. We compile the exporter from the pinned `sources.prometheus-nats-exporter` commit with `Containerfiles/prometheus-nats-exporter.Containerfile`. The source track is the 0.20 minor line. The vendor image is Alpine and unsigned, and no UBI-based exporter exists. See [Build track](/architecture/build-track--01a18382f2d2.md).

## Trust class

`internal`. We verify our `ubi9-micro` base against the release key of `infrashift/trusted-base-images`. See [Upstream trust classes](/architecture/upstream-trust-classes--01a18382f3fb.md).

The binary cross-check compares our binary with the binary in `docker.io/natsio/prometheus-nats-exporter`, trust class `none`, tier `best-effort`. We looked for a signature and found none. `cosign download signature` and `cosign tree` show no supply-chain artifacts. The vendor and our build use different Go patches. The goreleaser environment is not pinned data. Thus a byte mismatch proves nothing. See [ADR-004: Dual provenance is an observation, not a gate](/decisions/adr-004-dual-provenance-is-an-observation-not-a-gate--01a18382f4a6.md).

## Enforcement

See `versions.json` for the current value. On 2026-10-28 the value was `enforce`.

The image joined in `observe` mode. Its first PR, PR #29, merged on 2026-10-13 with a green check. The merge was two minutes after a review comment. For each architecture, the comment showed one Critical and seven High `stdlib` findings with a fix. It also showed the namespace `quarantine`. This PR is the reason for the rule "observe is not a pass". See [ADR-001: Observe enforcement mode](/decisions/adr-001-observe-enforcement-mode--01a18382f44e.md) and [Toolchain pins](/architecture/toolchain-pins--01a18382f31f.md).

The image moved to `enforce` on 2026-10-14. Before the move, a review on a `ubi9-micro` with the pcre2 fix (PR #32) was clean on both architectures. It had zero blocking, zero waived and zero recorded findings, and the namespace `trusted`.

## Variants and platforms

One variant, `runtime`. Architectures: `amd64`, `arm64`. The upstream index also has arm/v6 and arm/v7. We do not build them.

## Runtime

* Port: 7777, the upstream default. It is above 1024, so user 1001 needs no capability.
* The exporter has no state and no configuration file. /var/lib/prometheus-nats-exporter exists only as HOME and WORKDIR.
* Command: the upstream `--help`. Thus the image starts and stops. A deployment gives the endpoint flags and the NATS monitoring URL, for example `-varz -connz -subz -healthz -jsz=all http://127.0.0.1:8222`.
* User: 1001.

## Notes

* The flags come from the upstream `.goreleaser.yml`: `-trimpath`, `-s -w`, `CGO_ENABLED=0`, and the version without its leading `v`.
* goreleaser also passes `-X main.commit` and `-X main.date`, but `main.go` declares only `version`. The linker ignores those two flags. Thus we do not copy them, and there is no `shortCommit`.
* The Containerfile captures the version output and compares all of it. A wrong ldflags path still links, and the binary then reports 0.0.0.
* Licence: Apache-2.0.
* Consumer: `infrashift/ansible-collection-infrashift-hashistack`, terraform/live/nats, as a sidecar behind an mTLS metrics door.

## Issues and waivers

Open issues:

* [Mirror pins and the prometheus-nats-exporter source are behind the 2026-10-28 drift report](/issues/mirror-pins-and-the-prometheus-nats-exporter-source-are-behind-the-2026-10-28-drift-report--01a1838a139f.md)

Resolved issues:

* [The go1.26 toolchain pin 1.26.6 put 8 stdlib findings into every Go build](/issues/the-go1-26-toolchain-pin-1-26-6-put-8-stdlib-findings-into-every-go-build--01a1838a13e9.md)
* [The ubi9-minimal base pins were behind the sibling repository on 2026-10-28](/issues/the-ubi9-minimal-base-pins-were-behind-the-sibling-repository-on-2026-10-28--01a1838a1487.md)
* [The ubi9-micro base pins were behind the sibling repository on 2026-10-14](/issues/the-ubi9-micro-base-pins-were-behind-the-sibling-repository-on-2026-10-14--01a1838a1439.md)

Measurements:

* [On 2026-10-28 every build leg was trusted and every mirror leg was quarantined](/findings/on-2026-10-28-every-build-leg-was-trusted-and-every-mirror-leg-was-quarantined--01a1838a6fc5.md)
* [Go 1.26.6 put 8 stdlib findings into prometheus-nats-exporter on 2026-10-13](/findings/go-1-26-6-put-8-stdlib-findings-into-prometheus-nats-exporter-on-2026-10-13--01a1838a6f27.md)

## Related

* [nats](/images/nats--01a183832e00.md): the server that it monitors.
* [ADR-001: Observe enforcement mode](/decisions/adr-001-observe-enforcement-mode--01a18382f44e.md)
* [Toolchain pins](/architecture/toolchain-pins--01a18382f31f.md)
* [Images overview](/images/images-overview--01a1837da526.md)
* [Move an image from observe to enforce](/operations/move-an-image-from-observe-to-enforce--01a18383dac5.md)
