# bluecat

`bluecat` is an **unofficial [Fedora Atomic Desktop / Kinoite](https://fedoraproject.org/atomic-desktops/kinoite/)
based desktop image** built as a **[bootc](https://bootc-dev.github.io/bootc/) /
[OCI](https://opencontainers.org/) image**. It is intended as a ready-to-install
[KDE Plasma](https://kde.org/plasma-desktop/) desktop with selected hardware,
gaming, container and developer defaults.

The project publishes:

- a signed OCI image at `ghcr.io/echocat/bluecat`
- a rolling offline installer ISO at
  <https://download.bluecat.echocat.org/latest/bluecat.iso>

> [!NOTE]
> `bluecat` is **not affiliated with, endorsed by, or produced by the Fedora
> Project or Red Hat, Inc.** The word "Fedora" is used only descriptively to
> identify the upstream software this image is built from. Official, unmodified
> Fedora software is available from the [Fedora Project](https://fedoraproject.org/).

> [!IMPORTANT]
> This image is not fully open source. It may include proprietary NVIDIA driver
> components from RPM Fusion nonfree, and it can optionally download proprietary
> Microsoft Xbox Wireless Adapter firmware after explicit local user consent.
> See [License And Legal Notes](#license-and-legal-notes).

## What Is Included

- [Fedora Atomic Desktop / Kinoite](https://fedoraproject.org/atomic-desktops/kinoite/) style [KDE Plasma](https://kde.org/plasma-desktop/) desktop, remixed and rebranded as `bluecat`.
- [NVIDIA](https://www.nvidia.com/) driver stack from [RPM Fusion nonfree](https://rpmfusion.org/), with kernel modules built during image creation and signed with the bluecat [MOK](docs/secure-boot.md) for Secure Boot. See [`docs/nvidia.md`](docs/nvidia.md).
- [xone, the open-source Xbox controller driver](https://github.com/medusalix/xone), plus a bluecat activator that [can automatically install the Microsoft Xbox Wireless Adapter firmware locally when needed](docs/xbox-firmware.md).
- [Flathub](https://flathub.org/) enabled system-wide on first boot, using the unfiltered Flathub catalog.
- [Brave](https://brave.com/) installed from Flathub on first boot as the default browser replacement; the Firefox RPM from the base image is removed.
- [Nix](https://nixos.org/) package manager in multi-user daemon mode.
- [Distrobox](https://distrobox.it/) is installed, optimal for developers.
- Gaming tools:
  - [Steam](https://store.steampowered.com/about/)
  - [Lutris](https://lutris.net/)
  - [MangoHud](https://github.com/flightlessmango/MangoHud)
  - [Gamescope](https://github.com/ValveSoftware/gamescope)
  - [vkBasalt](https://github.com/DadSchoorse/vkBasalt)
  - [Winetricks](https://github.com/Winetricks/winetricks).
- [RustDesk](https://rustdesk.com/) for remote access.
- Virtualization tools ([QEMU/KVM](https://www.qemu.org/), [virt-manager](https://virt-manager.org/), [libvirt](https://libvirt.org/) / installed but not enabled by default).
- Desktop and hardware utilities such as codecs, VA-API-related pieces, [YubiKey](https://www.yubico.com/) / [FIDO2](https://fidoalliance.org/fido2/) tools, [rclone](https://rclone.org/), [dislocker](https://github.com/Aorimn/dislocker), `htop`, `mc` and common USB/PCI diagnostics.
- A local [TPM2 disk unlock manager](docs/luks-tpm2.md) for enabling or disabling TPM2 unlock on LUKS2 devices listed in `/etc/crypttab`.

## Installation

### Fresh Install From ISO

Download the latest rolling installer ISO:

- ISO: <https://download.bluecat.echocat.org/latest/bluecat.iso>
- SHA256: <https://download.bluecat.echocat.org/latest/bluecat.iso.sha256>
- MD5: <https://download.bluecat.echocat.org/latest/bluecat.iso.md5>

Verify the download if possible:

```bash
sha256sum -c bluecat.iso.sha256
```

Write the ISO to a USB drive with a normal image writer, for example [Rufus](https://rufus.ie/) on Windows, [balenaEtcher](https://etcher.balena.io/) on macOS, or [Fedora Media Writer](https://fedoraproject.org/workstation/download) on Linux. Then boot it and follow the installer. The ISO embeds the bluecat OCI image as an offline payload, so the initial system deployment does not need to pull the image from the registry. After installation, the system is configured to receive future updates from the signed release image at `ghcr.io/echocat/bluecat:44`.

### Rebase An Existing Fedora Atomic System

On an existing Fedora Atomic / Kinoite style system, use the signed rebase
helper:

```bash
curl -fsSL https://raw.githubusercontent.com/echocat/bluecat/main/scripts/rebase-signed | sudo bash
sudo systemctl reboot
```

On bootc-native systems, you can also switch directly:

```bash
sudo bootc switch ghcr.io/echocat/bluecat:44
sudo systemctl reboot
```

## First Boot And Automatic Setup

The image enables several setup tasks automatically:

1. Secure Boot MOK enrollment prompt, only when UEFI Secure Boot is enabled and the bluecat MOK certificate is not enrolled yet.
2. Flathub system remote setup.
3. Brave Flatpak installation from Flathub. If the network is unavailable, this is retried later.
4. Nix writable directory setup and `nix-daemon` activation.
5. NVIDIA and xone module autoload configuration.

> [!IMPORTANT]
> If Secure Boot is enabled, complete the blue MokManager enrollment after the prompt asks you to reboot. Without MOK enrollment, Secure Boot can reject the NVIDIA and xone modules; NVIDIA-only systems may fail to reach a graphical login because `nouveau` and `nova_core` are blacklisted for the proprietary NVIDIA driver stack.
> 
> See [`docs/secure-boot.md`](docs/secure-boot.md) for the full Secure Boot / MOK procedure and manual fallback commands.

## Optional Feature Activation

### Xbox Wireless Adapter Firmware

The `xone` driver is included, but the proprietary Microsoft Xbox Wireless Adapter firmware is not shipped, bundled or downloaded during the image build. It is only needed for the USB wireless dongle, not for wired controllers or Bluetooth.

To enable it locally on an installed system:

```bash
sudo enable-xone-firmware
```

The same flow is available from the desktop application menu as **Enable Xbox Wireless Adapter Firmware**. The activator shows a disclaimer, requires explicit confirmation, creates a local systemd unit, downloads the firmware from the pinned Microsoft / Windows Update URL, and verifies the extracted firmware against a pinned SHA256 hash.

Details and undo steps: [`docs/xbox-firmware.md`](docs/xbox-firmware.md).

### TPM2 Disk Unlock

If the installed system uses LUKS2 and has a TPM2 device, TPM2 unlock can be enabled or disabled after installation:

```bash
sudo manage-luks-tpm
```

The same flow is available from the desktop application menu as **Manage LUKS TPM**. It keeps the normal LUKS passphrase as fallback and uses `systemd-cryptenroll` for the actual TPM2 enrollment.

Details and undo steps: [`docs/luks-tpm2.md`](docs/luks-tpm2.md).

### Virtualization Services

Virtualization packages are installed, but libvirt services are not enabled by default. Enable the services you need on the installed system.

## License And Legal Notes

The files authored by this project are licensed under the MIT license, see [`LICENSE`](LICENSE). That license applies only to this repository's own build recipes, scripts, configuration and documentation.

It does **not** apply to third-party software integrated into or installed by the resulting system, including Fedora packages, RPM Fusion packages, proprietary NVIDIA components, the xone driver, optional Microsoft firmware, Flathub apps, Brave, Steam, RustDesk, Nix, Nushell or other upstream components. Each component is governed by its own license and terms.

Important references:

- [`NOTICE.md`](NOTICE.md) - third-party notices and attributions
- [`docs/legal.md`](docs/legal.md) - component and licensing boundaries
- [`docs/nvidia.md`](docs/nvidia.md) - NVIDIA component notes
- [`docs/xbox-firmware.md`](docs/xbox-firmware.md) - Xbox firmware opt-in flow
- [`docs/luks-tpm2.md`](docs/luks-tpm2.md) - TPM2 unlock manager for LUKS2 devices
- [`docs/secure-boot.md`](docs/secure-boot.md) - MOK enrollment and verification

## Development

Developer documentation, local build commands, CI behavior, image tags and publishing details live in [`DEVELOPMENT.md`](DEVELOPMENT.md).
