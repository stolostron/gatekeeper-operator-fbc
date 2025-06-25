#! /bin/bash

set -e

if [[ $(basename "${PWD}") != "gatekeeper-operator-fbc" ]]; then
  echo "error: Script must be run from the base of the repository."
  exit 1
fi

echo "Using drop version OCP-Gatekeeper map:"
yq '.' drop-versions.yaml

ocp_versions=$(yq -r 'keys[]' drop-versions.yaml)

shouldPrune() {
  oldest_version="$(yq ".[\"${1}\"].drop" drop-versions.yaml).99"

  [[ "$(printf "%s\n%s\n" "${2}" "${oldest_version}" | sort --version-sort | tail -1)" == "${oldest_version}" ]]

  return $?
}

for ocp in ${ocp_versions}; do
  cp -i -v "catalog-template-$(yq ".[\"${ocp}\"].version" drop-versions.yaml).yaml" "catalog-template-${ocp//./-}.yaml" || true
done

oldest_catalog=$(find catalog-template-v*.yaml | head -1)

# Prune old X.Y channels
echo "# Pruning channels:"
for channel in $(yq '.entries[] | select(.schema == "olm.channel").name' "${oldest_catalog}"); do
  echo "  Found channel: ${channel}"
  for ocp_version in ${ocp_versions}; do
    if shouldPrune "${ocp_version}" "${channel}"; then
      echo "  - Pruning channel from OCP ${ocp_version}: ${channel} ..."
      yq '.entries[] |= select(.schema == "olm.channel") |= del(select(.name == "'"${channel}"'"))' -i "catalog-template-${ocp_version//./-}.yaml"

      continue
    fi

    # Prune old bundles from channels
    for entry in $(yq '.entries[] | select(.schema == "olm.channel") | select(.name == "'"${channel}"'").entries[].name' "${oldest_catalog}"); do
      version=${entry#*\.v}
      if shouldPrune "${ocp_version}" "${version}"; then
        echo "  - Pruning entry from OCP ${ocp_version}: ${entry}"
        yq '.entries[] |= select(.schema == "olm.channel") |= select(.name == "'"${channel}"'").entries[] |= del(select(.name == "'"${entry}"'"))' -i "catalog-template-${ocp_version//./-}.yaml"
      fi
    done
  done
done
echo

# Prune old bundles
echo "# Pruning bundles:"
for bundle_image in $(yq '.entries[] | select(.schema == "olm.bundle").image' "${oldest_catalog}"); do
  bundle_version=$(skopeo inspect --override-os=linux --override-arch=amd64 "docker://${bundle_image}" | jq -r ".Labels.version")
  echo "  Found version: ${bundle_version}"
  pruned=0
  for ocp_version in ${ocp_versions}; do
    if shouldPrune "${ocp_version}" "${bundle_version#v}"; then
      echo "  - Pruning bundle ${bundle_version} from OCP ${ocp_version} ..."
      echo "    (image ref: ${bundle_image})"
      yq '.entries[] |= select(.schema == "olm.bundle") |= del(select(.image == "'"${bundle_image}"'"))' -i "catalog-template-${ocp_version//./-}.yaml"
    else
      ((pruned+=1))
    fi
  done
  if ((pruned == $(yq 'keys | length' drop-versions.yaml))); then
    echo "Nothing pruned--exiting."
    break
  fi
done
