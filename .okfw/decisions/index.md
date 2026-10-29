# decisions

<!-- okfw:generated — maintained by okfw; edits here are overwritten -->

## Concepts

* [ADR-001: Observe enforcement mode](adr-001-observe-enforcement-mode--01a18382f44e.md) - ADR-001 lets a new upstream go through review in observe mode: violations do not make the pipeline red, but they send the image to quarantine/.
* [ADR-002: No latest tag](adr-002-no-latest-tag--01a18382f469.md) - ADR-002 publishes no latest tag for any image, because it has no clear meaning and invites a -dev image into production.
* [ADR-003: Quarantine is a documented state](adr-003-quarantine-is-a-documented-state--01a18382f486.md) - ADR-003 makes quarantine/ a permanent state for images with violations, with full evidence and only an immutable tag.
* [ADR-004: Dual provenance is an observation, not a gate](adr-004-dual-provenance-is-an-observation-not-a-gate--01a18382f4a6.md) - ADR-004 records our binary hash next to the vendor hash, gates only that the comparison is done and well-formed, and never gates on the result.
* [ADR-005: Pin cosign to v2.6.1](adr-005-pin-cosign-to-v2-6-1--01a18382f4c6.md) - ADR-005 pins cosign to v2.6.1 so that our attestation layout matches the sibling repository; both repositories must move to v3 together.
* [ADR-006: Never pass --replace to cosign attest](adr-006-never-pass-replace-to-cosign-attest--01a18382f4e6.md) - ADR-006 bans the --replace flag on cosign attest, because it deletes vendor attestations and overwrites the SBOM of the other architecture.
* [ADR-007: The wiki is the tracker of record](adr-007-the-wiki-is-the-tracker-of-record--01a18382f505.md) - ADR-007 makes the .okfw/ wiki the place for issues, plans and findings; GitHub issues and the old .ai/ files point to it.
* [Decisions overview](decisions-overview--01a1837da541.md) - The decisions that shape this project, one ADR concept each, and the defects of the reference repo that we guard against.
* [Defects of the reference repo and their guards](defects-of-the-reference-repo-and-their-guards--01a18382f526.md) - The nine defects of trusted-base-oci-images that this repository did not repeat, and the mechanical guard for each one.

