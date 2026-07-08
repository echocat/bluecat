#!/usr/bin/env bash
# =============================================================================
# image-setup.sh  (runs in stage 2 / final)
# =============================================================================
# Installs runtime packages, registers the signed modules taken over from
# stage 1 (depmod) and applies sensible desktop defaults.
# =============================================================================
set -euo pipefail

# shellcheck source=container/common.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"

echo "==> Enabling RPM Fusion (runtime packages: NVIDIA userspace)"
retry rpm-ostree install -y \
  "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${FEDORA_MAJOR_VERSION}.noarch.rpm" \
  "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${FEDORA_MAJOR_VERSION}.noarch.rpm"

# ---------------------------------------------------------------------------
# NVIDIA kmod package built in stage 1. Installing it satisfies the
# `nvidia-kmod` dependency of the userspace packages, so dnf/rpm-ostree does
# NOT pull akmod-nvidia (whose %post fails as root inside the build).
# The pre-built RPM was stashed under /tmp/bluecat-rpms by build-modules.sh.
# ---------------------------------------------------------------------------
echo "==> Installing pre-built kmod-nvidia from stage 1"
rpm-ostree install -y /tmp/bluecat-rpms/kmod-nvidia-*.rpm

# ---------------------------------------------------------------------------
# NVIDIA userspace (driver libraries, NO kernel modules - those already come
# signed from stage 1).
# ---------------------------------------------------------------------------
echo "==> NVIDIA userspace packages"
rpm-ostree install -y \
  xorg-x11-drv-nvidia \
  xorg-x11-drv-nvidia-cuda \
  libva-nvidia-driver \
  libva-utils \
  vulkan-loader \
  nvidia-modprobe \
  nvidia-settings

# ---------------------------------------------------------------------------
# Re-apply the signed .ko files on top of whatever the kmod RPM installed,
# so the modules that end up in the image are the ones signed with our MOK.
# The signed tree was stashed under /tmp/bluecat-signed by build-modules.sh.
# ---------------------------------------------------------------------------
echo "==> Re-applying signed NVIDIA modules"
if [[ -d /tmp/bluecat-signed ]]; then
  for signed_nvidia_dir in /tmp/bluecat-signed/usr/lib/modules/*/extra/nvidia; do
    [[ -d "${signed_nvidia_dir}" ]] || continue
    modules_dir="${signed_nvidia_dir%/extra/nvidia}"
    kver="$(basename "${modules_dir}")"
    rm -rf "/usr/lib/modules/${kver}/extra/nvidia"
  done
  cp -a /tmp/bluecat-signed/. /
  rm -rf /tmp/bluecat-signed
fi
rm -rf /tmp/bluecat-rpms

# ---------------------------------------------------------------------------
# Sensible desktop defaults.
# This section is grouped here on purpose -> extend it to add more packages.
# ---------------------------------------------------------------------------
echo "==> Desktop defaults / common tools"
# dnf5-plugins provides `dnf copr`, which is needed further below to enable the
# Ghostty COPR before installing it. policycoreutils-python-utils provides
# `semanage`, needed further below to label the RustDesk hbbs/hbbr binaries.
# TODO Check if we can add mesa-va-drivers-freeworld  later, again
rpm-ostree install -y \
  gstreamer1-plugins-good \
  gstreamer1-plugins-bad-free \
  gstreamer1-plugin-openh264 \
  usbutils \
  pciutils \
  mokutil \
  newt \
  kbd \
  fuse \
  fuse-libs \
  htop \
  mc \
  dislocker \
  rclone \
  dnf5-plugins \
  make \
  git \
  python3-tkinter \
  yubikey-manager \
  fido2-tools \
  pam-u2f \
  policycoreutils-python-utils

# ---------------------------------------------------------------------------
# Scanning + network service discovery.
#   sane-backends / *-drivers-scanners : SANE scanner stack + scanner drivers
#   sane-airscan                        : driverless eSCL/WSD scanning over IP
#   ipp-usb                             : exposes IPP-over-USB devices as network
#                                         printers/scanners (driverless)
#   avahi + nss-mdns                    : mDNS/DNS-SD (.local) discovery, needed
#                                         for driverless network scanning/printing
# Services (avahi-daemon etc.) are intentionally NOT enabled here; the base
# image's presets decide that.
# ---------------------------------------------------------------------------
echo "==> Scanning + network service discovery"
rpm-ostree install -y \
  sane-backends \
  sane-backends-drivers-scanners \
  sane-airscan \
  ipp-usb \
  avahi \
  nss-mdns

# ---------------------------------------------------------------------------
# xone firmware: the proprietary Microsoft firmware is NOT shipped and NOT
# downloaded during the build. The image only ships the local opt-in activator
# /usr/bin/enable-xone-firmware (via system_files/); cabextract is the tool it
# needs at runtime to extract the firmware after the user explicitly opts in.
# See docs/xbox-firmware.md.
# ---------------------------------------------------------------------------
echo "==> Installing cabextract (needed by enable-xone-firmware at runtime)"
rpm-ostree install -y cabextract

# ---------------------------------------------------------------------------
# Gaming stack (RPM Fusion). The .i686 multilib variants are pulled in on
# purpose (Bazzite-style) so 32-bit titles under Steam/Wine get the MangoHud
# overlay and vkBasalt post-processing too.
# ---------------------------------------------------------------------------
echo "==> Gaming stack"
rpm-ostree install -y \
  steam \
  steam-devices \
  lutris \
  mangohud.x86_64 \
  mangohud.i686 \
  gamescope \
  vkBasalt.x86_64 \
  vkBasalt.i686 \
  winetricks

# ---------------------------------------------------------------------------
# Virtualization. Packages are only installed here; the libvirt/incus daemons
# are intentionally NOT enabled and no user groups are configured.
# ---------------------------------------------------------------------------
echo "==> Virtualization (install only, services not enabled)"
rpm-ostree install -y \
  qemu-kvm \
  virt-install \
  virt-manager \
  virt-viewer \
  libvirt \
  incus

# ---------------------------------------------------------------------------
# Containers: ship distrobox and remove the base-image `toolbox`.
#
# As with the fedora-logos swap and the firefox removal above, use `dnf remove`
# (NOT `rpm-ostree override remove`) to avoid a persistent override that would
# be re-evaluated - and fail - on later transactions on the target system.
# ---------------------------------------------------------------------------
echo "==> Containers: distrobox in, toolbox out"
rpm-ostree install -y distrobox
if rpm -q toolbox >/dev/null 2>&1; then
  dnf -y remove toolbox
else
  echo "    toolbox not installed; nothing to remove"
fi

# ---------------------------------------------------------------------------
# Ghostty terminal from the maintainer's COPR. `dnf copr` is provided by
# dnf5-plugins (installed further above). The COPR repo is left enabled on
# purpose so ghostty keeps receiving updates via `rpm-ostree upgrade`.
# ---------------------------------------------------------------------------
echo "==> Ghostty (COPR scottames/ghostty)"
dnf -y copr enable scottames/ghostty
rpm-ostree install -y ghostty

# ---------------------------------------------------------------------------
# Nushell from the upstream Gemfury repo. The repo definition is shipped via
# system_files/etc/yum.repos.d/fury-nushell.repo. gpgcheck=0 is used because the
# Gemfury RPMs are NOT GPG-signed (the key only signs repo metadata); integrity
# relies on HTTPS transport. See the comment in that .repo file. The repo is
# left enabled so nushell keeps receiving updates via `rpm-ostree upgrade`.
# ---------------------------------------------------------------------------
echo "==> Nushell (Gemfury repo)"
rpm-ostree install -y nushell

# ---------------------------------------------------------------------------
# RustDesk (remote desktop). There is no suitable repo, so the release RPM is
# installed directly from GitHub. The version is pinned via RUSTDESK_VERSION
# (passed in as ENV from the Containerfile / build.env).
#
# The RPM ships the relay/server helpers /usr/bin/hbbs and /usr/bin/hbbr. On a
# regular system RustDesk's post-install would label them; inside the image
# build we set the SELinux file context ourselves and relabel the files so the
# label is baked into the image.
# ---------------------------------------------------------------------------
echo "==> RustDesk ${RUSTDESK_VERSION} (direct RPM from GitHub)"
rpm-ostree install -y \
  "https://github.com/rustdesk/rustdesk/releases/download/${RUSTDESK_VERSION}/rustdesk-${RUSTDESK_VERSION}-0.x86_64.rpm"

echo "==> RustDesk: SELinux file context for hbbs/hbbr"
semanage fcontext -a -t NetworkManager_dispatcher_exec_t '/usr/bin/hbbs'
semanage fcontext -a -t NetworkManager_dispatcher_exec_t '/usr/bin/hbbr'
restorecon -v '/usr/bin/hbbs'
restorecon -v '/usr/bin/hbbr'

# ---------------------------------------------------------------------------
# NVIDIA: modeset (module option) + nouveau/nova_core blacklist.
#
# The actual kernel command-line args are shipped the bootc-native way via
# system_files/usr/lib/bootc/kargs.d/00-nvidia.toml. The modprobe option below
# is a separate layer (module load-time option) and complements them.
# ---------------------------------------------------------------------------
echo "==> Enabling NVIDIA modeset"
cat > /usr/lib/modprobe.d/nvidia-bluecat.conf <<'EOF'
options nvidia-drm modeset=1 fbdev=1
EOF

# ---------------------------------------------------------------------------
# Update the module registry for the shipped kernel.
# ---------------------------------------------------------------------------
echo "==> depmod for the shipped kernel"
for kver in /usr/lib/modules/*/; do
  kver="$(basename "${kver}")"
  if [[ -f "/usr/lib/modules/${kver}/vmlinuz" ]]; then
    echo "    depmod ${kver}"
    depmod -a "${kver}"
  fi
done

# ---------------------------------------------------------------------------
# Load the modules at boot.
# ---------------------------------------------------------------------------
echo "==> Auto-load configuration"
cat > /usr/lib/modules-load.d/nvidia-bluecat.conf <<'EOF'
nvidia
nvidia_modeset
nvidia_uvm
nvidia_drm
EOF

cat > /usr/lib/modules-load.d/xone-bluecat.conf <<'EOF'
xone-dongle
xone-gip
EOF

# ---------------------------------------------------------------------------
# Rebranding (Fedora Remix trademark compliance).
#
# This image combines unmodified Fedora software with non-Fedora software
# (NVIDIA from RPM Fusion, the xone driver). The Fedora trademark guidelines
# for such a "Remix" require that the Fedora branding packages are removed or
# replaced so the produced image does not carry Fedora trademarks, and that it
# is clearly identified as not being provided by the Fedora Project.
#
# We therefore:
#   1. replace fedora-logos with the neutral, trademark-free generic-logos,
#   2. rewrite os-release to identify the system as "bluecat" (ID_LIKE=fedora),
#   3. (optional) apply echocat branding assets shipped via system_files/.
# ---------------------------------------------------------------------------
echo "==> Rebranding: replacing fedora-logos with generic-logos"
# fedora-logos carries the Fedora trademarks; generic-logos is the neutral
# replacement provided by Fedora for exactly this purpose.
#
# IMPORTANT: use `dnf swap`, NOT `rpm-ostree override remove ... --install ...`.
# In an image build, `rpm-ostree override remove` records a persistent override
# in the deployment (RemovedBasePackages: fedora-logos + LayeredPackages:
# generic-logos). That override "sticks" to the deployment and is re-evaluated
# on every later rpm-ostree transaction on the target system. Since fedora-logos
# is already gone, that re-evaluation fails with
#   "error: No installed package matches 'fedora-logos'"
# and breaks operations like `rpm-ostree initramfs --enable` (and can interfere
# with updates). `dnf` manipulates the /usr tree directly during the build and
# leaves no such override/layer state behind.
if rpm -q fedora-logos >/dev/null 2>&1; then
  dnf -y swap fedora-logos generic-logos
else
  echo "    fedora-logos not installed; ensuring generic-logos is present"
  dnf -y install generic-logos
fi

# ---------------------------------------------------------------------------
# Default browser: remove the Firefox RPM and ship Brave as a Flatpak instead.
#
# Firefox is a base-image RPM. There is no per-user way to remove an RPM (they
# are system-wide), so we remove it from the image entirely. Brave cannot be
# baked into the image as a Flatpak (Flatpaks live in /var, which is not part
# of the immutable image), so it is installed on first boot by
# bluecat-install-brave.service (see system_files/). Flathub is enabled on
# first boot by bluecat-add-flathub.service.
#
# As with the logos swap above, use `dnf remove`, NOT `rpm-ostree override
# remove`, to avoid a persistent override that would break later transactions.
echo "==> Default browser: removing Firefox RPM (Brave Flatpak installed on first boot)"
if rpm -q firefox >/dev/null 2>&1; then
  dnf -y remove firefox firefox-langpacks
else
  echo "    firefox not installed; nothing to remove"
fi

# Enable our first-boot units (shipped via system_files/) using the preset we
# ship in /usr/lib/systemd/system-preset/70-bluecat.preset. This is the same
# mechanism Fedora uses for flatpak-add-fedora-repos.service and creates the
# multi-user.target.wants symlinks in the image.
echo "==> Enabling bluecat first-boot services"
systemctl preset \
  bluecat-add-flathub.service \
  bluecat-install-brave.service \
  bluecat-enroll-mok.service

echo "==> Rebranding: rewriting os-release"
# Preserve the upstream Fedora version for traceability of the base.
FEDORA_VERSION_ID="$(. /usr/lib/os-release 2>/dev/null; echo "${VERSION_ID:-${FEDORA_MAJOR_VERSION}}")"
REPO_URL="https://github.com/echocat/bluecat"
cat > /usr/lib/os-release <<EOF
NAME="bluecat"
PRETTY_NAME="bluecat ${FEDORA_VERSION_ID}"
ID="bluecat"
ID_LIKE="fedora"
VERSION="${FEDORA_VERSION_ID}"
VERSION_ID="${FEDORA_VERSION_ID}"
VARIANT="Atomic Desktop"
VARIANT_ID="atomic-desktop"
ANSI_COLOR="0;38;2;0;111;179"
LOGO="bluecat-logo-icon"
BOOTLOADER_NAME="bluecat ${FEDORA_VERSION_ID}"
HOME_URL="${REPO_URL}"
SUPPORT_URL="${REPO_URL}/issues"
BUG_REPORT_URL="${REPO_URL}/issues"
DOCUMENTATION_URL="${REPO_URL}"
EOF
# /etc/os-release should point at the canonical file.
ln -sf ../usr/lib/os-release /etc/os-release
# bootupd uses /etc/system-release as the UEFI firmware entry label source.
echo "bluecat release ${FEDORA_VERSION_ID}" > /etc/system-release

# echocat branding assets: rendered by `mise branding` from assets/branding/
# and shipped via system_files/, so they are already in place at this point
# (icon, full logo, Plymouth watermark, SDDM logo). The os-release LOGO above
# references "bluecat-logo-icon"; the matching icon is at
# /usr/share/pixmaps/bluecat-logo-icon.svg and in the hicolor theme.
echo "==> Rebranding: applying echocat branding assets"
if [[ -e /usr/share/pixmaps/bluecat-logo-icon.svg ]]; then
  echo "    logo icon present: /usr/share/pixmaps/bluecat-logo-icon.svg"
else
  echo "    NOTE: no bluecat logo icon found; run 'mise branding' and commit" \
       "the generated system_files/ assets. generic-logos remains the base."
fi

# KDE Plasma's application launcher defaults to the active icon theme's
# start-here/start-here-kde icon. The hicolor aliases cover fallback lookups;
# copying into Breeze covers the default Plasma theme, which otherwise finds its
# own icon before falling back to hicolor.
if [[ -e /usr/share/pixmaps/bluecat-logo-icon.svg ]]; then
  KDE_LAUNCHER_ICON_NAMES=(
    start-here
    start-here-kde
    start-here-kde-symbolic
  )

  mkdir -p /usr/share/icons/hicolor/scalable/places
  for icon_name in "${KDE_LAUNCHER_ICON_NAMES[@]}"; do
    cp -f /usr/share/pixmaps/bluecat-logo-icon.svg \
      "/usr/share/icons/hicolor/scalable/places/${icon_name}.svg"
  done

  for icon_theme in /usr/share/icons/breeze /usr/share/icons/breeze-dark; do
    [[ -d "${icon_theme}" ]] || continue

    for icon_dir in "${icon_theme}"/places/*; do
      [[ -d "${icon_dir}" ]] || continue

      for icon_name in "${KDE_LAUNCHER_ICON_NAMES[@]}"; do
        cp -f /usr/share/pixmaps/bluecat-logo-icon.svg \
          "${icon_dir}/${icon_name}.svg"
      done
    done
  done
fi

# Refresh the icon cache so the new hicolor icons are picked up.
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
  gtk-update-icon-cache -f /usr/share/icons/hicolor >/dev/null 2>&1 || true
fi

# Plymouth boot splash.
#
# The default "bgrt" theme and "spinner" both use the two-step plugin with
# ImageDir=/usr/share/plymouth/themes/spinner and load the watermark from the
# fixed filename watermark.png in that dir (there is no WatermarkImage=
# directive to set). So the watermark must live at spinner/watermark.png.
#
# IMPORTANT: that directory is owned by the rpm package plymouth-theme-spinner.
# We must NOT ship our watermark straight there via system_files/, because a
# later `rpm-ostree install`/`override` re-checks out the package directory and
# drops non-packaged files (this is exactly why it went missing before). So the
# branding task stages the watermark in our own, non-packaged directory
# (/usr/share/bluecat/branding/) and we copy it into the spinner theme HERE,
# after the last rpm-ostree transaction, right before `ostree container commit`.
#
# We also do NOT run `plymouth-set-default-theme -R` (it regenerates the theme
# dir and drops the file). Instead, after copying the watermark, rebuild the
# shipped initramfs with dracut's OSTree module explicitly enabled. A plain
# dracut rebuild can omit ostree-prepare-root and break switch-root.
PLY_SRC="/usr/share/bluecat/branding/plymouth-watermark.png"
PLY_DST="/usr/share/plymouth/themes/spinner/watermark.png"
if [[ -e "${PLY_SRC}" && -d /usr/share/plymouth/themes/spinner ]]; then
  cp -f "${PLY_SRC}" "${PLY_DST}"
  echo "    Plymouth watermark installed: ${PLY_DST}"
else
  echo "    NOTE: no staged Plymouth watermark (${PLY_SRC}); run 'mise branding'" \
       "and commit the generated system_files/ assets."
fi

echo "==> Rebuilding initramfs for bluecat boot splash"
if ! command -v dracut >/dev/null 2>&1; then
  echo "ERROR: dracut not found; cannot rebuild initramfs for bluecat branding." >&2
  exit 1
fi
if [[ ! -x /usr/lib/ostree/ostree-prepare-root ]]; then
  echo "ERROR: ostree-prepare-root not found; refusing to rebuild an initramfs without OSTree support." >&2
  exit 1
fi

initramfs_count=0
for kernel_module_dir in /usr/lib/modules/*/; do
  kver="$(basename "${kernel_module_dir}")"
  [[ -f "/usr/lib/modules/${kver}/vmlinuz" ]] || continue

  initramfs_count=$((initramfs_count + 1))
  echo "    dracut ${kver}"
  dracut --force --no-hostonly --add ostree \
    "/usr/lib/modules/${kver}/initramfs.img" "${kver}"
done

if (( initramfs_count == 0 )); then
  echo "ERROR: no shipped kernel found under /usr/lib/modules; cannot rebuild initramfs." >&2
  exit 1
fi

echo "==> image-setup.sh done"
