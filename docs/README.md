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
   [drop-versions.yaml](../drop-versions.yaml) map, which maps an OCP version to the version of the
   operator that should be dropped from the catalog.

3. Once PRs from Konflux corresponding to the addition or removal of the application are opened, for
   additions, run the [`pipeline-patch.sh`](../build/pipeline-patch.sh) script to patch the incoming
   pipeline with relevant updates:

   ```shell
   ./build/pipeline-patch.sh
   ```

## Updating the catalog entries

1. To add or update a staged bundle:

   - Adding a bundle:

     - Run the [`add-bundle.sh`](../build/add-bundle.sh) script to add catalog entries into
       [`catalog-template.yaml`](../catalog-template.yaml) giving the Konflux bundle image as an
       argument. The image can be found on the Konflux console in the Application in the Components
       tab. For example:

       ```shell
       ./build/add-bundle.sh quay.io/redhat-user-workloads/gatekeeper-tenant/gatekeeper-operator-X-Y/gatekeeper-operator-bundle-X-Y@sha256:<sha>
       ```

   - Updating a bundle SHA:

     - Do a repo-wide find/replace for the SHA in question, replacing the old SHA with the new one.
       Of particular importance are [`image-stage.txt`](../image-stage.txt) and the
       `catalog-template-v*.yaml` files.

2. Pruning previous catalogs without compelling reason is not allowed since it's already been
   deployed to customers. However, we can prune catalogs for unreleased versions of OCP.

   Update the OCP version <-> operator version map, [drop-versions.yaml](../drop-versions.yaml),
   with the version of the operator to drop for any unreleased OCP version.

3. Run the [build/generate-catalog.sh](../build/generate-template.sh) to regenerate the catalog
   template files and re-render the catalog for the template files:

   ```bash
   ./build/generate-catalog.sh
   ```
