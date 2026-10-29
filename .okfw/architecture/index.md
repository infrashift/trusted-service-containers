# architecture

<!-- okfw:generated — maintained by okfw; edits here are overwritten -->

## Concepts

* [Architecture overview](architecture-overview--01a1837da50c.md) - The parts of the system, the two tracks, the three actors, and how an image moves from build to trusted or quarantine.
* [Build track](build-track--01a18382f2d2.md) - How the build track compiles a pinned source commit onto our ubi9-micro base, and what each of the three Containerfile stages does.
* [Dual signing at release](dual-signing-at-release--01a18382f3b7.md) - The release actor signs twice: a keyed signature with no transparency log entry, then a keyless signature with one.
* [Mirror track](mirror-track--01a18382f29c.md) - How the mirror track copies a vendor image by its index digest, keeps all referrers, and never rebuilds it.
* [Mission and core principles](mission-and-core-principles--01a18382f27f.md) - The mission of the repository and its seven core principles, each with a link to the concept that explains it.
* [Pinned upstream keyrings and identities](pinned-upstream-keyrings-and-identities--01a18382f417.md) - Why we verify against a committed copy of each upstream keyring, and why the notation class pins a signing identity as well as a root.
* [Pins and tracks in versions.json](pins-and-tracks-in-versions-json--01a18382f304.md) - The rules for pins and tracks in versions.json: full digests only, 40-hex source commits, anchored track regexes that change only in their own PR.
* [Promotion](promotion--01a18382f371.md) - How the release actor reads the signed verdict and copies an image, byte-identical, from development/ to trusted/ or quarantine/.
* [Registry namespaces and cleanup](registry-namespaces-and-cleanup--01a18382f3dd.md) - The three GHCR namespaces, how long each keeps images, and the narrow rules that limit cleanup to development/.
* [Release tags and manifest lists](release-tags-and-manifest-lists--01a18382f392.md) - Which tags each track gets in trusted/ and quarantine/, why there is no latest tag, and why only the build track gets manifest lists.
* [Repository layout](repository-layout--01a18382f432.md) - The top-level directories and files of the repository and what each one holds.
* [Required labels on built images](required-labels-on-built-images--01a18382f2eb.md) - The five labels that each built image must carry, and why the ARGs behind them must be declared again after the runtime FROM.
* [The digest is the claim](the-digest-is-the-claim--01a18382f2b9.md) - Why mirrored images carry no labels of ours, and the five digest checks that three actors make at three stages.
* [The review actor re-derives the facts](the-review-actor-re-derives-the-facts--01a18382f356.md) - The review actor resolves digests live from GHCR and reads the trust class from versions.json, never from the build evidence.
* [The three actors](the-three-actors--01a18382f33a.md) - The Build, Review and Release actors: what each one does, which GitHub environment holds its key, and why a Review signature proves human approval.
* [Toolchain pins](toolchain-pins--01a18382f31f.md) - Why the Go toolchain pin goes stale, why a stdlib finding is our compiler's, and why GOTOOLCHAIN is never a version string.
* [Upstream trust classes](upstream-trust-classes--01a18382f3fb.md) - The four trust classes, the key that each class verifies the upstream signature against, and the three signature states that the policy accepts.

