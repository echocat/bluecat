# =============================================================================
# bluecat - Fedora Atomic (Kinoite) bootc/OCI image
# =============================================================================
# Two-stage build:
#
#   Stage 1 (builder):  Builds the kernel modules (NVIDIA akmod from RPM Fusion,
#                       xone from Git source) and signs them with the local MOK
#                       certificate.
#   Stage 2 (final):    The actual bootc image based on Kinoite. Takes over the
#                       signed modules + runtime packages and ships the PUBLIC
#                       certificate.
#
# The PRIVATE signing key is only used in stage 1 via a BuildKit secret and
# does NOT end up in the final image.
# =============================================================================

ARG FEDORA_MAJOR_VERSION
ARG BASE_IMAGE

# =============================================================================
# Stage 1: build and sign the kernel modules
# =============================================================================
FROM ${BASE_IMAGE}:${FEDORA_MAJOR_VERSION} AS builder

ARG FEDORA_MAJOR_VERSION
ARG XONE_REPO="https://github.com/medusalix/xone.git"
ARG XONE_REF

# The signing key is passed as a BuildKit secret (id=mok_key), NOT as an ARG,
# so it never lands in the layer history. The public cert is copied in.
COPY certs/mok.der /tmp/certs/mok.der
COPY certs/mok.crt /tmp/certs/mok.crt

COPY container/common.sh /tmp/common.sh
COPY container/build-modules.sh /tmp/build-modules.sh

# Enable RPM Fusion (free + nonfree) for the NVIDIA akmod, install the build
# tooling, build + sign the modules. The result lives under
# /tmp/out/usr/lib/modules/<kernel>/... and is taken over in stage 2.
# ARGs are passed explicitly as ENV into the script.
RUN --mount=type=secret,id=mok_key,target=/tmp/certs/mok.key \
    FEDORA_MAJOR_VERSION="${FEDORA_MAJOR_VERSION}" \
    XONE_REPO="${XONE_REPO}" \
    XONE_REF="${XONE_REF}" \
    /tmp/build-modules.sh

# =============================================================================
# Stage 2: final bootc image
# =============================================================================
FROM ${BASE_IMAGE}:${FEDORA_MAJOR_VERSION} AS final

ARG FEDORA_MAJOR_VERSION
ARG BASE_IMAGE
ARG RUSTDESK_VERSION
ARG IMAGE_CREATED
ARG IMAGE_REVISION
ARG IMAGE_VERSION

# ---------------------------------------------------------------------------
# OCI image metadata. Do NOT use Fedora as vendor/title - this is an
# unofficial, independent image (Fedora Remix), not a Fedora product.
# ---------------------------------------------------------------------------
LABEL org.opencontainers.image.title="bluecat" \
      org.opencontainers.image.description="Unofficial Fedora Atomic based desktop image (not affiliated with the Fedora Project or Red Hat)" \
      org.opencontainers.image.vendor="echocat" \
      org.opencontainers.image.source="https://github.com/echocat/bluecat" \
      org.opencontainers.image.url="https://github.com/echocat/bluecat" \
      org.opencontainers.image.documentation="https://github.com/echocat/bluecat" \
      org.opencontainers.image.licenses="MIT AND LicenseRef-third-party" \
      org.opencontainers.image.created="${IMAGE_CREATED}" \
      org.opencontainers.image.revision="${IMAGE_REVISION}" \
      org.opencontainers.image.version="${IMAGE_VERSION}" \
      org.opencontainers.image.base.name="${BASE_IMAGE}:${FEDORA_MAJOR_VERSION}"

# ---------------------------------------------------------------------------
# Ship the public MOK cert inside the image (informational / for the mokutil
# docs; the actual enrollment happens on the target system's firmware).
# ---------------------------------------------------------------------------
COPY certs/mok.der /etc/pki/echocat/mok.der
COPY certs/cosign.pub /etc/pki/containers/bluecat-cosign.pub
COPY system_files/ /

# ---------------------------------------------------------------------------
# Ship the legal/attribution documentation inside the image so it travels with
# the OCI artifact (Fedora Remix notice, NVIDIA/third-party notices).
# ---------------------------------------------------------------------------
COPY NOTICE.md /usr/share/doc/bluecat/NOTICE.md
COPY docs/legal.md /usr/share/doc/bluecat/legal.md
COPY docs/nvidia.md /usr/share/doc/bluecat/nvidia.md
COPY docs/xbox-firmware.md /usr/share/doc/bluecat/xbox-firmware.md
COPY LICENSE /usr/share/doc/bluecat/LICENSE

# ---------------------------------------------------------------------------
# Take over the signed kernel modules from stage 1.
# ---------------------------------------------------------------------------
COPY --from=builder /tmp/out/ /

COPY container/common.sh /tmp/common.sh
COPY container/image-setup.sh /tmp/image-setup.sh

# ---------------------------------------------------------------------------
# Runtime packages + configuration.
# ---------------------------------------------------------------------------
RUN FEDORA_MAJOR_VERSION="${FEDORA_MAJOR_VERSION}" \
    RUSTDESK_VERSION="${RUSTDESK_VERSION}" \
    /tmp/image-setup.sh && \
    rm -f /tmp/common.sh && \
    rm -f /tmp/image-setup.sh && \
    ostree container commit

# bootc lint (validates, among other things, that the image is bootable/rebasable).
RUN bootc container lint
