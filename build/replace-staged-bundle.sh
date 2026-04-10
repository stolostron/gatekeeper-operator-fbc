#! /bin/bash

if [[ ${PWD} != $(git rev-parse --show-toplevel) ]]; then
  echo "error: Script must be run from the base of the repository."
  exit 1
fi

# Fix sed issues on mac by using GSED
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
SED="sed"
if [ "${OS}" == "darwin" ]; then
  SED="gsed"
fi

bundle_old=$(git diff -U0 -- image-stage.txt | grep -E '^-.*gatekeeper-operator-bundle.*sha256:[a-f0-9]+$')
bundle_new=$(git diff -U0 -- image-stage.txt | grep -E '^\+.*gatekeeper-operator-bundle.*sha256:[a-f0-9]+$')

old_count=$(printf '%s' "${bundle_old}" | grep -c .)
new_count=$(printf '%s' "${bundle_new}" | grep -c .)

if [[ ${old_count} == 0 && ${new_count} == 0 ]]; then
  echo "No bundle digest changes found"
  exit 0
fi

if [[ ${old_count} != 1 || ${new_count} != 1 ]]; then
  echo "Old bundle: ${bundle_old}"
  echo "New bundle: ${bundle_new}"
  echo "Error: expected exactly one bundle digest change"
  exit 1
fi

old_sha=$(printf '%s' "${bundle_old}" | grep -oE 'sha256:[a-f0-9]+$')
new_sha=$(printf '%s' "${bundle_new}" | grep -oE 'sha256:[a-f0-9]+$')
application=$(printf '%s' "${bundle_new}" | grep -oE 'gatekeeper-operator-[0-9]+-[0-9]+')

echo "Application: ${application}"
echo "Old bundle SHA: ${old_sha}"
echo "New bundle SHA: ${new_sha}"

if [[ -z "${old_sha}" || -z "${new_sha}" ]]; then
  echo "Error: Could not bundle SHAs to replace in image-stage.txt"
  exit 1
fi

# Find all yaml files and replace the old SHA with the new SHA in all of them
find . -type f -name "*.yaml" \
  -exec echo "Updating SHA in {}" \; \
  -exec ${SED} -i "s/${old_sha}/${new_sha}/g" {} \;

# Regenerate the catalog
./build/generate-catalog.sh
