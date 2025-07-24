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

for template_file in catalog-template-v*.yaml; do
  if [[ -n $(yq '.entries[] | select(.image == "*'"${bundle_digest}"'")' "${template_file}") ]]; then
    echo "error: bundle entry already exists."
    exit 1
  fi

  # Add y-stream to ImageDigestMirrorSet
  y_stream=${bundle_version#v}
  y_stream=${y_stream%.*}
  y_stream=${y_stream//./-}
  echo "Adding y-stream to ImageDigestMirrorSet: ${y_stream}"
  yq '.spec.imageDigestMirrors[] |= .mirrors += [.mirrors[0] | sub("[0-9]-[0-9]{2}", "'"${y_stream}"'")]' -i .tekton/images-mirror-set.yaml
  yq '.spec.imageDigestMirrors[].mirrors |= unique' -i .tekton/images-mirror-set.yaml

  # Add bundle
  bundle_entry="
  image: ${bundle_image}
  schema: olm.bundle
  " yq '.entries += env(bundle_entry)' -i "${template_file}"

  # Add bundle to channels
  for channel in ${bundle_channels//,/ }; do
    echo "  Adding to channel: ${channel}"
    if [[ -z $(yq '.entries[] | select(.schema == "olm.channel") | select(.name == "'"${channel}"'")' "${template_file}") ]]; then
      latest_channel=$(yq '.entries[] | select(.schema == "olm.channel").name' "${template_file}" | grep -v stable | sort --version-sort | tail -1)
      new_channel=$(yq '.entries[] | select(.name == "'"${latest_channel}"'") | .name = "'"${channel}"'"' "${template_file}")

      echo "  Creating new ${channel} channel from ${latest_channel}"
      new_channel=${new_channel} yq '.entries += env(new_channel)' -i "${template_file}"
    fi

    replaces_version=$(yq '.entries[] | select(.schema == "olm.channel") | select(.name == "'"${channel}"'").entries[-1].name' "${template_file}")
    channel_entry="
    name: gatekeeper-operator-product.${bundle_version}
    replaces: ${replaces_version}
    skipRange: <${bundle_version#v}
    " yq '.entries[] |= select(.schema == "olm.channel") |= select(.name == "'"${channel}"'").entries += env(channel_entry)' -i "${template_file}"
  done
done

echo "* Adding bundle to image-stage.txt ..."
echo "${bundle_image}" >> image-stage.txt
