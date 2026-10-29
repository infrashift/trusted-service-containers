# operations

<!-- okfw:generated — maintained by okfw; edits here are overwritten -->

## Concepts

* [Add an upstream image](add-an-upstream-image--01a18383d9be.md) - The seven steps to add an image to versions.json: track, trust class, anchored track, pin, observe, a local scan, and the review comment.
* [Authenticate to DHI and the registries](authenticate-to-dhi-and-the-registries--01a18383d9e3.md) - Which registries the workflows log in to, which credential each login uses, and why the base image and mssql need no login.
* [Bump an upstream source within its track](bump-an-upstream-source-within-its-track--01a18383da54.md) - Take a drift-upstream proposal for a build-track source, add the hashes that it cannot compute, and merge it after a clean review.
* [Clean the development namespace](clean-the-development-namespace--01a18383db39.md) - Remove the development/ image versions of one PR with the cleanup workflow, or list and clean the namespace with Ops.mk.
* [Move an image from observe to enforce](move-an-image-from-observe-to-enforce--01a18383dac5.md) - Change the enforcement of an image to enforce after a review shows zero blocking findings on every leg.
* [Operations overview](operations-overview--01a1837da594.md) - Runbooks: add an upstream, bump a source, re-pin a toolchain or base, waive a CVE, move to enforce, read the review, and run the checks.
* [Re-pin a base image](re-pin-a-base-image--01a18383da79.md) - Move a base pin to the newest sibling release with drift-base.sh, check the toolchain at the same time, and rebuild every build-track image.
* [Re-pin a toolchain](re-pin-a-toolchain--01a18383da2e.md) - Move a Go toolchain pin to the current patch release, record goVersion, and rebuild every image that compiles with it.
* [Read the review comment before you merge an image PR](read-the-review-comment-before-you-merge-an-image-pr--01a18383daeb.md) - How to read the review comment before you merge an image PR: merge only when Blocking is 0 or the PR explains quarantine.
* [Run the checks locally](run-the-checks-locally--01a18383da08.md) - Run make -f Ops.mk validate, the repo gate and the policy tests on your machine before you open a pull request.
* [Set up a new repository from scratch](set-up-a-new-repository-from-scratch--01a18383db12.md) - A pointer to SETUP-ENVIRONMENTS.md: its twelve sections, from the preconditions to the first run, with the purpose of each section.
* [Waive a CVE](waive-a-cve--01a18383da9f.md) - How to add a waiver after no newer in-track release clears a finding, with a wiki issue as its ticket.

