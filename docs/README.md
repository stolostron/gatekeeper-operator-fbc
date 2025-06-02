# Managing the File Based Catalog

## Initializing the catalog from a current operator index

Use the [build/fetch-catalog.sh](../build/fetch-catalog.sh) script to pulling from the OCP vX.Y
index for the `gatekeeper-operator-product` operator package:

```bash
./build/fetch-catalog.sh X.Y gatekeeper-operator-product
```

## Adding or removing OCP versions

1. Update
   [konflux-release-data](https://gitlab.cee.redhat.com/releng/konflux-release-data/-/tree/main/tenants-config/cluster/stone-prd-rh01/tenants/gatekeeper-tenant),
   adding or removing OCP versions as needed.
2. If versions should be updated for an incoming or outgoing OCP version, update the
   [drop-versions.json](../drop-versions.json) map, which maps an OCP version to the version of the
   operator that should be dropped from the catalog.
3. Merge the PRs from Konflux corresponding to the addition or removal of the application. For
   additions, run the [pipeline-patch.sh](../.tekton/pipeline-patch.sh) script to patch the incoming
   pipeline with relevant updates.

## Updating the catalog entries

1. Update the [`catalog-template.yaml`](../catalog-template.yaml) with the new catalog entries (for
   example, any new channels, channel bundle entries, or bundles).
2. Pruning previous catalogs without compelling reason is not allowed since it's already been
   deployed to customers. However, we can prune catalogs for unreleased versions of OCP.

   Update the OCP version <-> operator version map, [drop-versions.json](../drop-versions.json),
   with the version of the operator to drop for any unreleased OCP version.

3. Run the [build/generate-catalog-template.sh](../build/generate-catalog-template.sh) to regenerate
   the catalog template files:

   ```bash
   ./build/generate-catalog-template.sh
   ```

4. Run the [render-catalog.sh](../build/render-catalog.sh) script to re-render the catalog for the
   template files:

   ```bash
   ./build/render-catalog.sh
   ```
