#! /bin/bash

dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

for konflux_file in "${dir}"/gatekeeper-operator-fbc-*.yaml; do
  echo "Updating $(basename "${konflux_file}") ..."

  # Add hermetic build
  has_hermetic=$(yq -o yaml '.spec.params | any_c(.name == "hermetic")' "${konflux_file}")
  if [[ ${has_hermetic} == false ]]; then
    yq '.spec.params |= . + [{"name":"hermetic","value":"true"}]' -i "${konflux_file}"
  fi

  # Add image build-arg
  has_build_args=$(yq -o yaml '.spec.params | any_c(.name == "build-args")' "${konflux_file}")
  catalog_version=$(yq 'keys[0]' "${dir}/../drop-versions.yaml")

  if [[ ${has_build_args} == false ]]; then
    version=$(echo "${konflux_file}" | grep -oE "[0-9]-[0-9]+")
    for next_version in $(yq 'keys[]' "${dir}/../drop-versions.yaml"); do
      if [[ "${version//-/.}" == "${next_version}" ]]; then
        catalog_version=${next_version}
      fi
    done

    yq '.spec.params |= . + [
      {
        "name":"build-args",
        "value":[
          "IMAGE=registry.redhat.io/openshift4/ose-operator-registry-rhel9:v'"${version//-/.}"'",
          "INPUT_DIR=catalog-'"${catalog_version//./-}"'"
        ]
      }]' -i "${konflux_file}"
  fi
done
