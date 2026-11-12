ARG OPM_IMAGE=quay.io/operator-framework/opm:latest
ARG ASSEMBLY_IMAGE=registry.access.redhat.com/ubi9/ubi-minimal:latest@sha256:ecb40c7bdfa5b0bb71e978c98c7cf56ce38edf1f8fb3561078acbc4b13698c07

# Assemble the selected catalog using its explicit channels and shared bundles.
FROM ${ASSEMBLY_IMAGE} AS assembly
USER 0
ARG INPUT_DIR

WORKDIR /tmp/catalog-workspace
COPY build/bundle-catalog.sh build/bundle-catalog.sh
COPY bundles/ bundles/
COPY bundles-legacy-format/ bundles-legacy-format/
# This ensures incorrectly cached layers aren't used:
RUN echo "Assembling ${INPUT_DIR}"
COPY ./${INPUT_DIR}/ ./${INPUT_DIR}/
RUN bash build/bundle-catalog.sh "${INPUT_DIR}"

# The builder image is expected to contain /bin/opm (with serve subcommand)
FROM ${OPM_IMAGE} as builder

# Copy the assembled FBC catalog into /configs, validate it, and pre-populate the serve cache
ARG INPUT_DIR
COPY ./${INPUT_DIR}/ /configs/gatekeeper-operator-product/
COPY --from=assembly /tmp/catalog-workspace/${INPUT_DIR}/bundles/ /configs/gatekeeper-operator-product/bundles/
RUN ["/bin/opm", "validate", "/configs"]
RUN ["/bin/opm", "serve", "/configs", "--cache-dir=/tmp/cache", "--cache-only"]

# The base image is expected to contain /bin/opm (with serve subcommand) and /bin/grpc_health_probe
FROM ${OPM_IMAGE}

COPY --from=builder /configs /configs
COPY --from=builder /tmp/cache /tmp/cache

# Set FBC-specific label for the location of the FBC root directory in the image
LABEL operators.operatorframework.io.bundle.mediatype.v1=registry+v1
LABEL operators.operatorframework.io.bundle.manifests.v1=manifests/
LABEL operators.operatorframework.io.bundle.metadata.v1=metadata/
LABEL operators.operatorframework.io.bundle.package.v1=gatekeeper-operator
LABEL operators.operatorframework.io.bundle.channels.v1=alpha
LABEL operators.operatorframework.io.metrics.builder=operator-sdk-v1.33.1
LABEL operators.operatorframework.io.metrics.mediatype.v1=metrics+v1
LABEL operators.operatorframework.io.metrics.project_layout=go.kubebuilder.io/v3
LABEL operators.operatorframework.io.index.configs.v1=/configs

ENTRYPOINT ["/bin/opm"]
CMD ["serve", "/configs", "--cache-dir=/tmp/cache"]
