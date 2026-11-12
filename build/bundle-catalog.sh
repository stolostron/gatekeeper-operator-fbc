#!/usr/bin/env bash

set -euo pipefail

if [[ -z "${1}" ]]; then
    echo "The catalog directory must be provided as an argument."
    exit 1
fi

BUNDLE_DIR="bundles"
if [[ "${1}" == "catalog-4-14" || "${1}" == "catalog-4-16" ]]; then
    BUNDLE_DIR="bundles-legacy-format"
fi

mkdir -p "${1}"/bundles

# Example input: '  - name: gatekeeper-operator-product.v3.20.0'
# Desired output: 'bundle-v3.20.0.yaml'
FILTER="/  - name: gatekeeper-operator-product.[^p]*$/"
# shellcheck disable=SC2016
NAMEF='"bundle-" $2 "." $3 "." $4 ".yaml"'

BUNDLES=$(awk -F'.' "${FILTER}"'{ print '"${NAMEF}"'}' "${1}/channels/"*".yaml" | sort | uniq)
(
    cd "${BUNDLE_DIR}"
    for file in ${BUNDLES}; do
        cp "$file" "../${1}/bundles/"
    done
)

## Special handling for some older "rebuild-only" releases
# Example input: '  - name: gatekeeper-operator-product.v0.2.3-0.1655383639.p'
# Desired output: 'bundle-v0.2.3-0.1655383639.p.yaml'
FILTER="/  - name: gatekeeper-operator-product.*.p/"
# shellcheck disable=SC2016
NAMEF='"bundle-" $2 "." $3 "." $4 "." $5 ".p.yaml"'

BUNDLES=$(awk -F'.' "${FILTER}"'{ print '"${NAMEF}"'}' "${1}/channels/"*".yaml" | sort | uniq)
(
    cd "${BUNDLE_DIR}"
    for file in ${BUNDLES}; do
        cp "$file" "../${1}/bundles/"
    done
)
