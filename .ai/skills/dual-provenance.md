# Dual provenance

The build track records the sha256 of the binary we built **and** of the same
binary from the vendor's official image.

**It is not a gate.** The policy requires only that the comparison was
performed (`DUAL_PROVENANCE_NOT_RECORDED`), is well-formed
(`DUAL_PROVENANCE_MALFORMED`), and used the pinned reference
(`DUAL_PROVENANCE_REFERENCE_UNPINNED`). The outcome never affects the decision.

We measured. Go builds are not reproducible here — for NATS we matched every
input visible to `go version -m` and the binary still differed. A mismatch is
the expected result and proves nothing; a *change* in the relationship is the
real signal.

Full measurements, the three defects the comparison caught, and the reasoning:
[`../../docs/build-track/dual-provenance.md`](../../docs/build-track/dual-provenance.md).

If anyone proposes promoting this to a gate, read that first.
