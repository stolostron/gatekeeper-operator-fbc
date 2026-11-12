# Managing the File Based Catalog

## Catalog layout

Each `catalog-<OCP>/` contains the package metadata and channels for one OCP catalog. Keeping
channels per catalog makes their bundle selection and upgrade paths explicit. Bundle metadata is
shared to avoid maintaining duplicate copies:

- `bundles/` contains the modern representation.
- `bundles-legacy-format/` contains the older representation used by OCP 4.14 and 4.16.

`build/bundle-catalog.sh` assembles a catalog by copying the bundles named in its channel entries.
`replaces` and `skips` references alone do not select bundles. Catalog entries and image builds do
not by themselves establish product support or publication.

## Adding a bundle

1. Obtain the intended bundle image pinned by its actual SHA256 digest. From the repository root,
   render it with `opm` and `yq`:

   ```shell
   ./build/add-bundle.sh <bundle-image>@sha256:<digest>
   ```

   This writes modern metadata to `bundles/`. Set `LEGACY_FORMAT=true` to write legacy metadata
   to `bundles-legacy-format/` instead; run it twice if both formats are needed. The script defaults
   to `./bin/opm` and `yq` on `PATH`; `OPM` and `YQ` override those locations. It refuses to
   overwrite an existing bundle file.
2. Review the rendered metadata. The script rewrites the bundle's own image reference to
   `PROD_REPO` (by default `registry.redhat.io/gatekeeper/gatekeeper-operator-bundle`), retaining
   the digest. Operator and operand references inside the bundle are not rewritten.
3. ***Manually*** Update the applicable OCP catalogs' version channels and, when appropriate,
   `stable`, reviewing the `replaces`, `skips` and `skipRange` edges. Keep `stable` a single
   forward-moving chain; an older stream's patch should not be appended behind a newer stream.
   Adding a bundle file alone does not put it in a catalog. Preserve previously published bundles
   and upgrade paths unless that catalog has not been officially published yet.
4. Review `.tekton/images-mirror-set.yaml` and the staging image references. The script does not
   update mirrors or channels. The intended staging approach uses production references; verify
   with QE that digest mirrors make the candidate bundle, operator and operand images available to
   test clusters.
5. Validate and build the affected catalogs, review their diffs, and test the staged catalogs and
   upgrade paths before release.

For a new staged digest of an existing bundle, the script will not overwrite the existing file.
Review the replacement metadata and staging references explicitly; there is no automatic staged
digest replacement workflow in this repository.

## Validating and building catalogs

Run `make opm` to install the pinned `opm`, then run `make validate-catalog` from the repository
root. This assembles and validates each catalog. The generated `catalog-*/bundles/` directories
are ignored by Git, and the assembly script does not remove existing files. Use a clean assembly
when checking the effects of removed entries so stale files cannot affect validation.

Build a catalog image with the target OCP version's `opm` image. Read `OPM_IMAGE` from that target's
`.tekton` build arguments; for example:

```shell
make build-image CATALOG=catalog-4-16 OPM_IMAGE=registry.redhat.io/openshift4/ose-operator-registry-rhel9:v4.16
```

`CATALOG` defaults to `catalog-5-0` and `OPM_IMAGE` defaults to upstream `opm:latest`. The
Dockerfile assembles a fresh catalog, validates it and pre-caches it with the supplied `opm` image.
A successful build checks catalog compatibility with that `opm` version; it does not prove runtime
compatibility, support, or a successful Konflux build.
