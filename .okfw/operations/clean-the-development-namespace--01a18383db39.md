---
id: "01a18383-db39-78aa-b65e-62e212203efb"
title: "Clean the development namespace"
type: "runbook"
tags:
  - "runbook"
  - "ghcr"
  - "cleanup"
created: "2026-10-28T12:16:59-05:00"
timestamp: "2026-10-28T12:24:43-05:00"
description: "Remove the development/ image versions of one PR with the cleanup workflow, or list and clean the namespace with Ops.mk."
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:24:43-05:00"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/scripts/cleanup-dev.sh"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/.github/workflows/cleanup-dev.yml"
    title: "cleanup-dev.yml"
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/Ops.mk"
    title: "Ops.mk"
---

# Clean the development namespace

This runbook removes old image versions from the `development/` namespace in GHCR. Never clean `trusted/` or `quarantine/`. Both hold signed images that other systems refer to. `quarantine/` is a documented state, not a place for unwanted images.

## Automatic cleanup

After a successful release, the [Cleanup Dev Images workflow](/supply-chain/cleanup-dev-images-workflow--01a18383d75b.md) deletes the `development/` versions of the released pull request. It deletes a version only when every tag on it belongs to that pull request.

## Clean one pull request by hand

1. Open the Actions tab and select `Cleanup Dev Images`.
2. Select "Run workflow".
3. Enter the pull request number in `pr_number`.
4. Keep `dry_run` set to `true`. Run the workflow.
5. Read the step summary. It lists each version that the workflow would delete, and each shared version that it keeps.
6. If the list is correct, run the workflow again with `dry_run` set to `false`.

## List a namespace

Run `make -f Ops.mk list-images target_namespace=development`. The target also accepts `trusted` and `quarantine`. It needs a `gh` login with access to the packages.

## Delete all of development/

WARNING: This target deletes each full `development/` package. It also deletes the in-progress images of every open pull request.

1. Make sure that no image pull request is open.
2. Run `make -f Ops.mk clean-ghcr-namespace target_namespace=development`.

The target refuses any namespace other than `development`.

## Related

* [Operations overview](/operations/operations-overview--01a1837da594.md)
* [Cleanup Dev Images workflow](/supply-chain/cleanup-dev-images-workflow--01a18383d75b.md)
* [Release Images workflow](/supply-chain/release-images-workflow--01a18383d737.md)
