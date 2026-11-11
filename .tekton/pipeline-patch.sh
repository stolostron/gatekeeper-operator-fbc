#! /bin/bash

dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

for konflux_file in "${dir}"/gatekeeper-operator-fbc-*.yaml; do
  echo "Updating $(basename "${konflux_file}") ..."

  # Clean up extra fields
  yq 'del(.metadata.creationTimestamp)' -i "${konflux_file}"
  yq 'del(.status)' -i "${konflux_file}"

  # Replace pipelineSpec with pipelineRef
  yq 'del(.spec.pipelineSpec)' -i "${konflux_file}"
  yq '.spec.pipelineRef = {
    "resolver":"git",
    "params":[
    { "name":"url", "value":"https://github.com/stolostron/konflux-build-catalog.git" },
    { "name":"revision", "value":"main" },
    { "name":"pathInRepo", "value":"pipelines/common-fbc.yaml" }]}' -i "${konflux_file}"

  # Add image build-arg
  has_build_args=$(yq -o yaml '.spec.params | any_c(.name == "build-args")' "${konflux_file}")

  if [[ ${has_build_args} == false ]]; then
    version=$(echo "${konflux_file}" | grep -oE "[0-9]-[0-9]+")
    if [[ ! -d "${dir}/../catalog-${version}" ]]; then
      echo "error: missing catalog directory catalog-${version}" >&2
      exit 1
    fi

    yq '.spec.params |= . + [
      {
        "name":"build-args",
        "value":[
          "OPM_IMAGE=registry.redhat.io/openshift'"${version%-*}"'/ose-operator-registry-rhel9:v'"${version//-/.}"'",
          "INPUT_DIR=catalog-'"${version}"'"
        ]
      }]' -i "${konflux_file}"
  fi
done
