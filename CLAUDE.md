# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository contains the File-Based Catalog (FBC) for the Gatekeeper Operator, which provides policy-based governance for Kubernetes clusters through Open Policy Agent (OPA) integration. The catalog manages operator bundles across multiple OpenShift Container Platform (OCP) versions.

## Common Development Commands

### Building and Validation
- `make validate-catalog` - Validate all catalog directories using opm
- `make build-image` - Build catalog container image using podman
- `make run-image` - Run catalog image locally on port 50051
- `make test-image` - Test the running catalog image with grpcurl

### Tool Installation
- `make opm` - Install/update the opm (Operator Package Manager) tool
- `make grpcurl` - Install/update grpcurl for testing

### Catalog Management Scripts
- `./build/fetch-catalog.sh X.Y gatekeeper-operator-product` - Initialize catalog from OCP vX.Y index
- `./build/add-bundle.sh <image-reference>` - Add a new bundle to catalog templates
- `./build/generate-catalog.sh` - Regenerate catalog template files and render catalogs

## Repository Structure

### Catalog Organization
- `catalog-4-14/`, `catalog-4-17/`, `catalog-4-19/`, `catalog-4-20/` - Generated catalogs for specific OCP versions
- Each catalog contains:
  - `bundles/` - Operator bundle definitions
  - `channels/` - Channel configurations (stable, candidate, etc.)
  - `package.yaml` - Package metadata

### Template Files
- `catalog-template-v1.yaml`, `catalog-template-v2.yaml`, `catalog-template-v3.yaml` - Template files defining catalog entries and channels
- Templates are processed to generate version-specific catalogs

### Configuration Files
- `drop-versions.yaml` - Maps OCP versions to operator versions that should be dropped from catalogs
- `image-stage.txt` - Contains staged bundle image references for releases
- `catalog.Dockerfile` - Multi-stage dockerfile for building catalog images

### Build Scripts
- `build/fetch-catalog.sh` - Fetches existing catalog data from OCP indexes
- `build/add-bundle.sh` - Adds bundle entries to catalog templates
- `build/generate-catalog.sh` - Processes templates and generates final catalogs

## Development Workflow

1. **Adding New Bundles**: Use `./build/add-bundle.sh` with the Konflux bundle image reference
2. **Updating Bundle SHAs**: Perform repo-wide find/replace for the SHA, updating `image-stage.txt` and template files
3. **Regenerating Catalogs**: Run `./build/generate-catalog.sh` after template changes
4. **Validation**: Always run `make validate-catalog` before committing changes

## Architecture Notes

- The repository uses a template-based approach where catalog templates are processed to generate OCP version-specific catalogs
- Bundle versioning follows semantic versioning with z-stream support (patch releases with timestamps)
- Channel management supports stable, candidate, and fast channels with proper upgrade paths
- Integration with Red Hat Konflux for CI/CD pipeline automation

## Testing

- Local testing requires running the catalog image and querying it with grpcurl
- `test/packageList.json` contains expected package list for validation
- Catalog validation uses the opm tool to ensure proper FBC format