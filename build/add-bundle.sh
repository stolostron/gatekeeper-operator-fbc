#! /bin/bash

set -e

if [[ $(basename "${PWD}") != "gatekeeper-operator-fbc" ]]; then
  echo "error: Script must be run from the base of the repository."
  exit 1
fi

bundle_image=${1}

if [[ -z "${bundle_image}" ]]; then
  echo "error: the bundle image to be added must be provided as a positional argument."
  exit 1
fi

# Parse bundle
bundle_json=$(skopeo inspect --override-os=linux --override-arch=amd64 "docker://${bundle_image}")
bundle_digest=$(echo "${bundle_json}" | jq -r ".Digest")
bundle_version=$(echo "${bundle_json}" | jq -r ".Labels.version")
bundle_channels=$(echo "${bundle_json}" | jq -r '.Labels["operators.operatorframework.io.bundle.channels.v1"]')

echo "* Found bundle: ${bundle_digest}"
echo "* Found version: ${bundle_version}"
echo "* Found channels: ${bundle_channels}"

if [[ -n $(yq '.entries[] | select(.image == "'"${bundle_image}"'")' catalog-template.yaml) ]]; then
  echo "error: bundle entry already exists."
  exit 1
fi

# Add bundle
bundle_entry="
  image: ${bundle_image}
  schema: olm.bundle
" yq '.entries += env(bundle_entry)' -i catalog-template.yaml

# Add bundle to channels
for channel in ${bundle_channels//,/ }; do
  echo "  Adding to channel: ${channel}"
  if [[ -z $(yq '.entries[] | select(.schema == "olm.channel") | select(.name == "'"${channel}"'")' catalog-template.yaml) ]]; then
    latest_channel=$(yq '.entries[] | select(.schema == "olm.channel").name' catalog-template.yaml | grep -v stable | sort --version-sort | tail -1)
    new_channel=$(yq '.entries[] | select(.name == "'"${latest_channel}"'") | .name = "'"${channel}"'"' catalog-template.yaml)

    echo "  Creating new ${channel} channel from ${latest_channel}"
    new_channel=${new_channel} yq '.entries += env(new_channel)' -i catalog-template.yaml
  fi

  replaces_version=$(yq '.entries[] | select(.schema == "olm.channel") | select(.name == "'"${channel}"'").entries[-1].name' catalog-template.yaml)
  channel_entry="
  name: gatekeeper-operator-product.${bundle_version}
  replaces: ${replaces_version}
  skipRange: <${bundle_version#v}
  " yq '.entries[] |= select(.schema == "olm.channel") |= select(.name == "'"${channel}"'").entries += env(channel_entry)' -i catalog-template.yaml
done
