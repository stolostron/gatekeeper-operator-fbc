# The builder image is expected to contain /bin/opm (with serve subcommand)
FROM quay.io/operator-framework/opm:latest as builder

# Copy FBC root into image at /configs and pre-populate serve cache
ADD catalog/ /configs
RUN ["/bin/opm", "serve", "/configs", "--cache-dir=/tmp/cache", "--cache-only"]

# The base image is expected to contain /bin/opm (with serve subcommand) and /bin/grpc_health_probe
FROM quay.io/operator-framework/opm:latest

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
