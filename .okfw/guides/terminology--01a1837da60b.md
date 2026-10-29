---
id: "01a1837d-a60b-7ca5-b9d5-01e2015fbe8e"
title: "Terminology"
type: "guide"
tags:
  - "guide"
  - "ste"
  - "terminology"
created: "2026-10-28T12:10:12-05:00"
timestamp: "2026-10-28T12:10:12-05:00"
description: "The controlled words of this project: one word for one thing, and one meaning for each word."
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:10:12-05:00"
---

# Terminology

Use these words with these meanings only. If you need a new word, add it here first.

## Rule

* Use one word for one thing. Do not use a synonym for variety.
* Use each word with one meaning.
* Write technical names (commands, paths, flags, file names) in code font.

## Product words

| Word | Meaning | Do not use |
|---|---|---|
| image | One service in the `images` map of `versions.json`, for example `nats`. | container, service image |
| variant | One published form of an image, for example the runtime or the `-dev` form. | flavor, edition |
| mirror track | Images that we copy from the vendor by digest and do not rebuild. `kind: mirror`. | proxy, re-host |
| build track | Images that we build from a pinned source commit onto our own base. `kind: build`. | rebuild, from-source track |
| leg | One image (and one architecture) in one workflow run. | job (alone), target |
| upstream | The vendor project or registry that an image comes from. | origin, vendor repo |
| source | A pinned upstream source commit in the `sources` map of `versions.json`. | checkout, tag |
| base | A pinned base image in the `bases` map, for example `ubi9-micro`. | OS image, parent |
| toolchain | A pinned compiler image in the `toolchains` map, for example `go1.26`. | builder, SDK |

## Supply-chain words

| Word | Meaning | Do not use |
|---|---|---|
| pin | A reference by full `sha256:` digest, or by a 40-hex commit for a source. Also the act of setting one. | lock, freeze |
| digest | The `sha256:` value that identifies one image or artifact. | hash, SHA |
| track (regex) | The anchored regex in `versions.json` that limits where a pin can go. | range, constraint |
| trust class | The `upstreamTrust` value: `dhi`, `notation`, `internal` or `none`. It decides signature checks only. | trust level |
| enforcement | The `enforcement` value of an image: `enforce` or `observe`. | mode, strictness |
| PDP | The policy decision point: `.github/pdp/policies.rego`, package `tsc.pdp`. | gate (alone), checker |
| finding | One vulnerability that the scanner (Grype) reports. | vuln, hit |
| blocking | A finding that stops promotion to `trusted/`. | failing |
| waiver | One entry in `.github/pdp/exceptions.yaml`, with an id `EXC-YYYY-NNNN` and an expiry of 90 days or less. | exception (alone), allowlist |
| verdict | The signed review result for one leg: `PASS` or `FAIL`, plus a namespace. | decision, result |
| actor | One of the three pipeline identities: `Build-Actor`, `Review-Actor`, `Release-Actor`. Each is a GitHub environment with its own key. | role, bot |
| evidence | The signed files that the build actor makes for one leg. The review actor does not trust them. | artifacts (alone) |
| drift | A newer upstream release, base or toolchain inside the track. The drift workflows report it. | staleness |

## Registry words

| Word | Meaning | Do not use |
|---|---|---|
| `development/` | The GHCR namespace for new builds before review. | staging, dev |
| `trusted/` | The GHCR namespace for images that have no violations, in `enforce` or `observe` mode. | prod, release |
| `quarantine/` | The GHCR namespace for images that have violations. In `enforce` mode the verdict is `FAIL`. In `observe` mode the verdict is `PASS`. It is a documented state, not an error. | rejected, failed |
| promotion | The copy of a reviewed image, byte-identical, from `development/` to `trusted/` or `quarantine/`. | release (alone), publish |

## Wiki words

| Word | Meaning | Do not use |
|---|---|---|
| concept | One markdown file in `.okfw/`. It holds one idea. | note, page, doc |
| bundle | One directory in `.okfw/`, with its generated `index.md`. | folder, section |
| overview | The concept that explains one bundle. Tag: `hub`. | readme, landing page |
| issue | A concept of kind `issue`. It records one problem or one task. | ticket, bug, TODO |
| plan | A concept of type `plan`. It records the steps of one piece of work. | proposal, spec |
