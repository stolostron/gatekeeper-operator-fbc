#!/usr/bin/env bash

set -euo pipefail

if [[ ! "${1:-}" =~ ^[^[:space:]@]+@sha256:[a-f0-9]{64}$ ]]; then
  echo "error: provide a bundle image pinned by its sha256 digest" >&2
  exit 1
fi

BUNDLE_IMAGE="${1}"
OPM=${OPM:-./bin/opm}
YQ=${YQ:-yq}
PROD_REPO=${PROD_REPO:-registry.redhat.io/gatekeeper/gatekeeper-operator-bundle}
LEGACY_FORMAT=${LEGACY_FORMAT:-false}
BUNDLES_DIR="bundles"
if [[ "${LEGACY_FORMAT}" == "true" ]]; then
  BUNDLES_DIR="bundles-legacy-format"
fi

# Render to a temporary file so the bundle can be checked before copying.
temporary_file=$(mktemp "${BUNDLES_DIR}/.bundle.XXXXXXXX")
trap 'rm -f -- "${temporary_file}" "${temporary_file}.bak"' EXIT

if [[ "${LEGACY_FORMAT}" == "true" ]]; then
  "${OPM}" render "${BUNDLE_IMAGE}" --migrate-level="none" -o yaml >"${temporary_file}"
else
  "${OPM}" render "${BUNDLE_IMAGE}" --migrate-level="bundle-object-to-csv-metadata" -o yaml >"${temporary_file}"
fi

# Rewrite the reference to the added bundle from pre-prod coordinates to the final location.
bundle_repo="${BUNDLE_IMAGE%@*}"
bundle_digest="${BUNDLE_IMAGE##*@}"
if [[ "${bundle_repo}" != "${PROD_REPO}" ]]; then
  sed -i.bak "s|${bundle_repo}@|${PROD_REPO}@|g" "${temporary_file}"
  echo "Rewrote ${bundle_repo} to ${PROD_REPO} (digest unchanged)"
fi
if ! grep -qF "${PROD_REPO}@${bundle_digest}" "${temporary_file}"; then
  echo "error: rendered bundle lacks ${PROD_REPO}@${bundle_digest}" >&2
  exit 1
fi

schema=$("${YQ}" -r '.schema // ""' "${temporary_file}")
package=$("${YQ}" -r '.package // ""' "${temporary_file}")
bundle_name=$("${YQ}" -r '.name // ""' "${temporary_file}")
modern_count=$("${YQ}" -r '[.properties[] | select(.type == "olm.csv.metadata")] | length' "${temporary_file}")
legacy_count=$("${YQ}" -r '[.properties[] | select(.type == "olm.bundle.object")] | length' "${temporary_file}")

if [[ "${schema}" != "olm.bundle" || "${package}" != "gatekeeper-operator-product" ]]; then
  echo "error: expected one Gatekeeper bundle, got schema '${schema}' and package '${package}'" >&2
  exit 1
fi
if [[ ! "${bundle_name}" =~ ^gatekeeper-operator-product[.][0-9A-Za-z._+-]+$ ]]; then
  echo "error: unexpected bundle name: ${bundle_name}" >&2
  exit 1
fi

if [[ "${LEGACY_FORMAT}" == "true" ]]; then
  if [[ "${modern_count}" != 0 || "${legacy_count}" == 0 ]]; then
    echo "error: expected legacy olm.bundle.object without modern metadata" >&2
    exit 1
  fi
else
  if [[ "${modern_count}" != 1 || "${legacy_count}" != 0 ]]; then
    echo "error: expected modern olm.csv.metadata without legacy bundle objects" >&2
    exit 1
  fi
fi

bundle_file="${BUNDLES_DIR}/bundle-${bundle_name#gatekeeper-operator-product.}.yaml"
if [[ -e "${bundle_file}" || -L "${bundle_file}" ]]; then
  echo "error: ${bundle_file} already exists; existing files are not overwritten" >&2
  exit 1
fi
cp "${temporary_file}" "${bundle_file}"
chmod 0644 "${bundle_file}"

echo "Created ${bundle_file}"
echo "Bundle image reference is ${PROD_REPO}@${bundle_digest}; update and review catalog channels separately."
