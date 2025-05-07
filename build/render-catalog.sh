#! /bin/bash

set -e

if [[ $(basename "${PWD}") != "gatekeeper-operator-fbc" ]]; then
  echo "error: Script must be run from the base of the repository."
  exit 1
fi

# Render the template to a catalog

##### Special case for OCP <=4.16 #####
echo "Rendering catalog with olm.bundle.object for OCP <=4.16 ..."
opm alpha render-template basic catalog-template-4-14.yaml -o=yaml >catalog-4-14.yaml
#######################################

catalog_templates=$(find catalog-template-*.yaml -not -name "catalog-template-4-14.yaml")

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

rm catalog-template-*.yaml
