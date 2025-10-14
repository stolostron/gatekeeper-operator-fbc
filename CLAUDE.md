# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This repository houses the File-Based Catalog (FBC) for the Gatekeeper Operator, which provides policy-based governance for Kubernetes clusters through Open Policy Agent integration. The FBC uses Operator Lifecycle Manager (OLM) standards to manage multiple operator versions across different OpenShift Container Platform (OCP) releases.

## Common Commands

### Validation and Testing
```bash
# Validate all catalog directories
make validate-catalog

# Build catalog image (builds for the first catalog-* directory found)
make build-image

# Run catalog image locally
make run-image

# Stop running catalog image
make stop-image

# Test catalog endpoint (requires running image)
make test-image
```

### Tools Installation
```bash
# Install/update opm (Operator Package Manager) to latest version
make opm

# Install/update grpcurl for testing
make grpcurl

# Clean up installed tools
make clean
```

### Catalog Management Scripts

**Initialize catalog from OCP index:**
```bash
# Fetch catalog from OCP vX.Y index for gatekeeper-operator-product package
./build/fetch-catalog.sh X.Y gatekeeper-operator-product
```

**Add a new bundle:**
```bash
# Add a Konflux bundle image to all catalog templates
./build/add-bundle.sh quay.io/redhat-user-workloads/gatekeeper-tenant/gatekeeper-operator-X-Y/gatekeeper-operator-bundle-X-Y@sha256:<sha>
```

**Regenerate catalogs:**
```bash
# Generate catalog templates and render all catalog directories
./build/generate-catalog.sh
```

**Patch Konflux pipelines:**
```bash
# Update Tekton pipeline configurations with proper references
./.tekton/pipeline-patch.sh
```

## Architecture Overview

### Catalog Structure

The repository maintains **multiple OCP version-specific catalogs** (e.g., `catalog-4-14/`, `catalog-4-17/`, `catalog-4-19/`, `catalog-4-20/`, `catalog-4-21/`) that are rendered from **template files** (`catalog-template-v1.yaml`, `catalog-template-v2.yaml`, `catalog-template-v3.yaml`). Each catalog directory contains:

- `bundles/` - Individual bundle YAML files (e.g., `bundle-v3.14.1.yaml`)
- `channels/` - Channel definitions (e.g., `channel-3.14.yaml`, `channel-stable.yaml`)
- `package.yaml` - Package metadata with default channel and description

### Version Management System

**`drop-versions.yaml`** - Central configuration mapping OCP versions to:
- `version`: Which catalog template version to use (`v1`, `v2`, `v3`)
- `drop`: Minimum operator version to include (older versions are pruned)

Example:
```yaml
4.20:
  version: v3
  drop: 3.14  # Versions < 3.14 are dropped from this OCP catalog
```

**`image-stage.txt`** - Tracks staged Konflux bundle images (not yet in production registry). The `generate-catalog.sh` script checks if these images are available in production and removes them from this file when they are.

### Image Reference Flow

1. **Konflux images** → Added to templates via `add-bundle.sh`
2. **Staged images** → Tracked in `image-stage.txt`
3. **Production images** → Scripts automatically replace Konflux references with `registry.redhat.io/gatekeeper/gatekeeper-operator-bundle@<digest>` during catalog generation

### Catalog Generation Process

The `generate-catalog.sh` script performs these operations:

1. **Replace staged images**: Swaps production registry references back to Konflux stage references for images in `image-stage.txt`
2. **Generate OCP-specific templates**: Copies versioned templates (v1/v2/v3) to OCP-specific templates based on `drop-versions.yaml`
3. **Prune old versions**: Removes channels, channel entries, and bundles that fall below the `drop` threshold for each OCP version
4. **Render catalogs**: Uses `opm alpha render-template` to convert templates to full catalogs:
   - OCP ≤4.16: Uses `olm.bundle.object` format
   - OCP >4.16: Uses `olm.csv.metadata` format (with migration flag)
5. **Decompose catalogs**: Splits monolithic YAML into directory structure with separate bundle/channel/package files
6. **Normalize references**: Replaces Konflux image URLs with production registry URLs in final output

### CI/CD Integration

**Tekton Pipelines** (`.tekton/` directory):
- Separate pipelines for each OCP version (e.g., `gatekeeper-operator-fbc-4-21-push.yaml`)
- `pipeline-patch.sh` updates these with:
  - Pipeline references to `stolostron/konflux-build-catalog`
  - Hermetic build settings
  - OCP-specific build arguments (`OPM_IMAGE` and `INPUT_DIR`)

### Key Constraints

- **Never prune released catalogs** - Only unreleased OCP versions can have bundles pruned
- **All scripts must run from repository root** - Scripts validate working directory is `gatekeeper-operator-fbc`
- **macOS compatibility** - Scripts detect macOS and use `gsed` instead of `sed`
- **Digest-based references** - All bundle images use SHA256 digests, not tags

## Important File Relationships

- `catalog-template-v*.yaml` → Source of truth for bundle definitions
- `drop-versions.yaml` → Controls which template version and pruning rules apply to each OCP version
- `image-stage.txt` → Temporary tracking for staged vs production images
- `.tekton/images-mirror-set.yaml` → Updated by `add-bundle.sh` when new y-streams are added
