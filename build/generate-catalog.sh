#! /bin/bash

set -e

if [[ $(basename "${PWD}") != "gatekeeper-operator-fbc" ]]; then
  echo "error: Script must be run from the base of the repository."
  exit 1
fi

# Fix sed issues on mac by using GSED
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
SED="sed"
if [ "${OS}" == "darwin" ]; then
  SED="gsed"
fi

# Replace the production images with stage references

while IFS= read -r staged_image; do
  echo "* Handling staged bundle ${staged_image} ..."

  staged_digest=${staged_image##*@}
  registry_image="registry.redhat.io/gatekeeper/gatekeeper-operator-bundle@${staged_digest}"

  if skopeo inspect --override-os linux --override-arch amd64 --no-tags --format '{{ printf "%s@%s" .Name .Digest }}' "docker://${registry_image}" 2>/dev/null; then
    echo "* skopeo inspect found production image. Removing from image-stage.txt ..."
    ${SED} -i "/${staged_digest}$/d" image-stage.txt
    continue
  fi

  for file in catalog-template-v*.yaml; do
    echo "* Handling ${file} ..."
    ${SED} -i -E "s%${registry_image}%${staged_image}%g" "${file}"
  done
done <image-stage.txt

########################################
# Generate the catalog template files #
########################################

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
  package_name=$(yq '.entries[] | select(.schema == "olm.bundle") | select(.image == "'"${bundle_image}"'").name' "${oldest_catalog}")
  bundle_version=${package_name//gatekeeper-operator-product./}
  echo "  Found version: ${bundle_version}"
  pruned=0
  for ocp_version in ${ocp_versions}; do
    if shouldPrune "${ocp_version}" "${bundle_version#v}"; then
      echo "  - Pruning bundle ${bundle_version} from OCP ${ocp_version} ..."
      echo "    (image ref: ${bundle_image})"
      yq '.entries[] |= select(.schema == "olm.bundle") |= del(select(.image == "'"${bundle_image}"'"))' -i "catalog-template-${ocp_version//./-}.yaml"
    else
      ((pruned += 1))
    fi
  done
  if ((pruned == $(yq 'keys | length' drop-versions.yaml))); then
    echo "Nothing pruned--exiting."
    break
  fi
done

####################################################
# Render the template files to catalog directories #
####################################################

##### Special case for OCP <=4.16 #####
echo "Rendering catalog with olm.bundle.object for OCP <=4.16 ..."
opm alpha render-template basic catalog-template-4-14.yaml -o=yaml >catalog-4-14.yaml
#######################################

catalog_templates=$(find catalog-template-[^v]*.yaml -not -name "catalog-template-4-14.yaml")

for catalog_template in ${catalog_templates}; do
  echo "Rendering catalog with olm.csv.metadata with ${catalog_template} ..."
  opm alpha render-template basic "${catalog_template}" -o=yaml --migrate-level=bundle-object-to-csv-metadata >"${catalog_template//-template/}"
done

# Decompose the catalog into files for consumability
catalogs=$(find catalog-*.yaml -not -name "catalog-template*.yaml")
rm -r catalog-*/

for catalog_file in ${catalogs}; do
  catalog_dir=${catalog_file%\.yaml}
  echo "Decomposing ${catalog_file} into directory for consumability: ${catalog_dir}/ ..."
  yq 'select(.schema == "olm.bundle")' -s '"'"${catalog_dir}"'/bundles/bundle-v" + (.properties[] | select(.type == "olm.package").value.version) + ".yaml"' "${catalog_file}"
  yq 'select(.schema == "olm.channel")' -s '"'"${catalog_dir}"'/channels/channel-" + (.name) + ".yaml"' "${catalog_file}"
  yq 'select(.schema == "olm.package")' -s '"'"${catalog_dir}"'/package.yaml"' "${catalog_file}"
  rm "${catalog_file}"
done

rm catalog-template-[^v]*.yaml

# Use oldest catalog to populate bundle names for reference
oldest_catalog=$(find catalog-* -type d | head -1)

for template_file in catalog-template-v*.yaml; do
  for bundle in "${oldest_catalog}"/bundles/*.yaml; do
    bundle_image=$(yq '.image' "${bundle}")
    bundle_name=$(yq '.name' "${bundle}")

    yq '.entries[] |= select(.image == "'"${bundle_image}"'").name = "'"${bundle_name}"'"' -i "${template_file}"
  done

  # Sort catalog
  yq '.entries |= (sort_by(.schema, .name) | reverse)' -i "${template_file}"
  yq '.entries |= 
    [(.[] | select(.schema == "olm.package"))] + 
   ([(.[] | select(.schema == "olm.channel"))] | sort_by(.name)) + 
   ([(.[] | select(.schema == "olm.bundle"))] | sort_by(.name))' -i "${template_file}"
done

# Replace the Konflux images with production images
for file in catalog-template-v*.yaml catalog-*/bundles/*.yaml; do
  ${SED} -i -E 's%quay.io/redhat-user-workloads/[^@]+%registry.redhat.io/gatekeeper/gatekeeper-operator-bundle%g' "${file}"
done
