#!/usr/bin/env bash
# =============================================================================
# build-modules.sh  (runs in stage 1 / builder)
# =============================================================================
# Builds and signs the out-of-tree kernel modules:
#   - NVIDIA (akmod-nvidia from RPM Fusion nonfree)
#   - xone   (from Git source, https://github.com/medusalix/xone)
#
# Result: signed .ko(.xz) under /tmp/out/usr/lib/modules/<kver>/extra/...
# This /tmp/out is taken over in stage 2 via COPY --from=builder.
#
# Expects:
#   /tmp/certs/mok.crt   (public, PEM)
#   /tmp/certs/mok.der   (public, DER)
#   /tmp/certs/mok.key   (PRIVATE, via --mount=type=secret)
#   ENV XONE_REPO / XONE_REF / FEDORA_MAJOR_VERSION
# =============================================================================
set -euo pipefail

# shellcheck source=image/setup/common.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"

: "${XONE_REPO:=https://github.com/medusalix/xone.git}"
: "${XONE_REF:=master}"

CERT_CRT="/tmp/certs/mok.crt"
CERT_KEY="/tmp/certs/mok.key"
OUT="/tmp/out"

echo "==> Determining kernel version"
# The Kinoite image ships exactly ONE kernel package.
KVER="$(rpm -q kernel-core --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}\n' | head -n1)"
if [[ -z "${KVER}" || "${KVER}" == *"is not installed"* ]]; then
  echo "ERROR: could not determine kernel version." >&2
  exit 1
fi
echo "    Kernel: ${KVER}"

echo "==> Enabling RPM Fusion (free + nonfree)"
retry dnf install -y \
  "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${FEDORA_MAJOR_VERSION}.noarch.rpm" \
  "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${FEDORA_MAJOR_VERSION}.noarch.rpm"

echo "==> Installing build dependencies"
# IMPORTANT: kernel-devel MUST match the kernel version of the base image
# exactly. If the matching kernel-devel is no longer in the current repo
# (kernel in the image older/newer than the repo state), the koji archives or
# a pinned repo may be required. We try the exact version and fail clearly.
dnf install -y \
  gcc gcc-c++ make git \
  kernel-headers \
  akmods \
  openssl mokutil \
  elfutils-libelf-devel \
  cabextract

if ! dnf install -y "kernel-devel-${KVER}"; then
  echo "ERROR: kernel-devel-${KVER} is not available." >&2
  echo "       The kernel in the base image does not match the repo state." >&2
  echo "       Fix: pin the base image tag or fetch kernel-devel from koji." >&2
  echo "       See README (TODO / roadmap)." >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Signing helper: signs a single .ko file with the MOK key.
# ---------------------------------------------------------------------------
SIGN_FILE="/usr/src/kernels/${KVER}/scripts/sign-file"
if [[ ! -x "${SIGN_FILE}" ]]; then
  echo "ERROR: sign-file not found at ${SIGN_FILE}" >&2
  exit 1
fi

sign_module() {
  local ko="$1"
  if [[ "${ko}" == *.xz ]]; then
    xz -d "${ko}"
    ko="${ko%.xz}"
  fi
  echo "    signing: ${ko}"
  "${SIGN_FILE}" sha256 "${CERT_KEY}" "${CERT_CRT}" "${ko}"
}

# Signed modules are staged under /tmp/bluecat-signed inside the output tree.
# Stage 2 lays them on top of the kmod RPM contents AFTER installing it, so the
# modules that end up in the final image are the ones signed with our MOK.
SIGNED="${OUT}/tmp/bluecat-signed"
mkdir -p "${SIGNED}/usr/lib/modules/${KVER}/extra"

# ===========================================================================
# NVIDIA (akmod-nvidia)
# ===========================================================================
echo "==> Building NVIDIA akmod"
# Install the akmod source package. Its %post scriptlet tries to build the
# module immediately and fails as root ("Not to be used as root"); that failure
# is non-critical here because we build explicitly with akmodsbuild below.
dnf install -y akmod-nvidia xorg-x11-drv-nvidia-cuda || true

# Locate the source RPM that akmod-nvidia dropped and build it against KVER.
# akmodsbuild is the tool that IS allowed to run as root (unlike `akmods`).
NVIDIA_SRPM="$(find /usr/src/akmods -name 'nvidia-kmod-*.src.rpm' | sort -V | tail -n1)"
if [[ -z "${NVIDIA_SRPM}" ]]; then
  echo "ERROR: nvidia-kmod src.rpm not found under /usr/src/akmods." >&2
  exit 1
fi
echo "    source: ${NVIDIA_SRPM}"

AKMOD_OUT="/tmp/akmod-nvidia"
mkdir -p "${AKMOD_OUT}"
# akmodsbuild refuses to run as root. The `akmods` wrapper solves this by
# invoking it as the unprivileged `akmods` user via runuser - we do the same.
chown -R akmods:akmods "${AKMOD_OUT}"
runuser -s /bin/bash -c \
  "akmodsbuild --kernels '${KVER}' --outputdir '${AKMOD_OUT}' '${NVIDIA_SRPM}'" \
  akmods

echo "==> Installing built kmod-nvidia RPM"
dnf install -y "${AKMOD_OUT}"/kmod-nvidia-*.rpm

# Stash the built kmod RPM so stage 2 can install it to satisfy the
# `nvidia-kmod` dependency of the userspace packages (this prevents dnf from
# pulling akmod-nvidia, whose %post fails as root). The signed .ko files are
# layered on top afterwards via COPY --from=builder.
mkdir -p "${OUT}/tmp/bluecat-rpms"
cp "${AKMOD_OUT}"/kmod-nvidia-*.rpm "${OUT}/tmp/bluecat-rpms/"

echo "==> Collecting + signing NVIDIA modules"
NVIDIA_SRC="$(dirname "$(find "/usr/lib/modules/${KVER}" -name 'nvidia.ko*' | head -n1)")"
if [[ -z "${NVIDIA_SRC}" || ! -d "${NVIDIA_SRC}" ]]; then
  echo "ERROR: NVIDIA modules not found." >&2
  exit 1
fi

find "${NVIDIA_SRC}" \( -name '*.ko' -o -name '*.ko.xz' \) | while read -r ko; do
  sign_module "${ko}"
done
cp -a "${NVIDIA_SRC}" "${SIGNED}/usr/lib/modules/${KVER}/extra/nvidia"

# ===========================================================================
# xone (from Git source)
# ===========================================================================
echo "==> Cloning xone (${XONE_REPO} @ ${XONE_REF})"
git clone "${XONE_REPO}" /tmp/xone
git -C /tmp/xone checkout "${XONE_REF}"

echo "==> xone firmware is NOT included (proprietary)."
echo "    The driver is built; the controller firmware must be fetched at"
echo "    runtime by the user via 'sudo enable-xone-firmware' (see README)."

echo "==> Building xone"
# xone ships an install.sh using DKMS; we build directly against KVER here and
# bypass DKMS (Atomic-friendly).
make -C "/usr/src/kernels/${KVER}" M=/tmp/xone modules

echo "==> Collecting + signing xone modules"
mkdir -p "${SIGNED}/usr/lib/modules/${KVER}/extra/xone"
find /tmp/xone -name '*.ko' | while read -r ko; do
  sign_module "${ko}"
  cp -a "${ko}" "${SIGNED}/usr/lib/modules/${KVER}/extra/xone/"
done

echo "==> Done. Signed modules under ${OUT}"
find "${OUT}" -name '*.ko*' -printf '    %p\n'
