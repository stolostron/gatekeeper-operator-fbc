# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This repository houses the File-Based Catalog (FBC) for the Gatekeeper Operator, which provides policy-based governance for Kubernetes clusters through Open Policy Agent integration. The FBC uses Operator Lifecycle Manager (OLM) standards to manage multiple operator versions across different OpenShift Container Platform (OCP) releases.

## Catalog work

For bundle additions, staged image references, validation, image builds, and OCP catalog changes,
read [docs/README.md](docs/README.md). Inspect the target catalog's channels and its `.tekton`
build arguments before making changes.

- Preserve bundles and upgrade paths in officially published catalogs; prune only catalogs that
  have not been officially published.
- `make validate-catalog` writes ignored bundle files and does not remove stale files. Use a clean
  assembly when checking removals.
- Catalog entries and successful builds do not establish product support or publication.

## Useful commands

Run these from the repository root. See `docs/README.md` for bundle formats, staging and validation
details.

```bash
make opm                 # Install the pinned opm
make validate-catalog    # Assemble and validate all catalogs
make build-image CATALOG=catalog-4-16 \
  OPM_IMAGE=registry.redhat.io/openshift4/ose-operator-registry-rhel9:v4.16
make run-image           # Start the built catalog image in a separate terminal
make test-image          # Test the running catalog endpoint
make stop-image          # Stop the catalog image
```

Use the target's `OPM_IMAGE` from its `.tekton` build arguments when building an image.
`build/add-bundle.sh <image>@sha256:<digest>` renders bundle metadata; update channels and mirrors
separately. `./.tekton/pipeline-patch.sh` modifies pipeline files for OCP component changes.
