# NOTICE

This file provides attribution and third-party notices for the `bluecat`
project and the OCI/bootc images it produces.

## Scope of the project license

The MIT license in [`LICENSE`](LICENSE) applies **only** to the files authored
by this project (build recipes, scripts, configuration and documentation in
this repository). It does **not** apply to any third-party software that is
pulled in at build time or shipped inside the resulting image. Each such
component is governed by its own license and terms; see below and
[`docs/legal.md`](docs/legal.md).

## Fedora (base)

`bluecat` is an **unofficial** image built from **Fedora** software (Fedora
Atomic Desktop / Kinoite). It is **not affiliated with, endorsed by, or
produced by the Fedora Project or Red Hat, Inc.**

Official, unmodified Fedora software is available from the Fedora Project at
<https://fedoraproject.org/>.

Fedora and the Infinity design logo are trademarks of Red Hat, Inc. This
project uses the word "Fedora" only descriptively (nominative use) to identify
the upstream software it is built from. The `fedora-logos`, `fedora-release`
and `fedora-release-notes` branding is replaced in the produced image so that
it does not carry Fedora trademarks.

## RPM Fusion

The NVIDIA kernel modules and userspace packages are obtained from
**RPM Fusion** (nonfree) — <https://rpmfusion.org/>. RPM Fusion is an
independent third-party repository, not part of Fedora.

## NVIDIA proprietary driver

The image may contain **proprietary NVIDIA driver components** (kernel module
built from RPM Fusion sources plus NVIDIA userspace libraries).

- NVIDIA components are subject to **NVIDIA's own license terms**.
- This project's MIT license does **not** apply to NVIDIA components.
- This project does **not** modify NVIDIA binaries.

See [`docs/nvidia.md`](docs/nvidia.md) for details.

## xone (Xbox controller driver)

`xone` is an independent open-source project
(<https://github.com/medusalix/xone>) licensed under its own terms (GPL-2.0).
The driver source is compiled during the build; no binaries from the xone
project are vendored into this repository.

## Microsoft Xbox Wireless Adapter firmware

The proprietary Microsoft Xbox Wireless Adapter firmware is **NOT** included in
this repository and **NOT** bundled into the image, and it is **NOT** downloaded
during the build. It can only be fetched **locally on the target system, after
an explicit user action**. See [`docs/xbox-firmware.md`](docs/xbox-firmware.md).

## Flathub and Brave

The image enables the **Flathub** Flatpak repository (<https://flathub.org/>)
system-wide on first boot. Nothing from Flathub is bundled into the image; the
remote is added on the target system at first boot.

The image installs the **Brave** browser from the official Brave RPM repository
during image creation. RPM signatures are verified against Brave's RPM signing
key before packages are installed into the image.

- Flathub applications are provided by **third parties** under their **own
  licenses and terms**; this project's MIT license does **not** apply to them.
- Brave is a product of **Brave Software, Inc.** and is subject to its own
  license and terms.
- The Firefox RPM from the Fedora base is removed from the image in favor of
  Brave.

See [`docs/legal.md`](docs/legal.md) for details.

## Gaming applications and tools

The image installs gaming-related software such as **Steam**, **Lutris**,
MangoHud, Gamescope, vkBasalt and Winetricks from Fedora, RPM Fusion or upstream
sources.

- Steam is proprietary Valve software and is governed by Valve's terms.
- Other gaming components are governed by their own upstream or package terms.
- This project's MIT license does **not** apply to these third-party
  applications and tools.

## RustDesk

The image installs **RustDesk** from the upstream GitHub RPM release. RustDesk is
governed by its own upstream license and terms. This project's MIT license does
**not** apply to RustDesk.

## Nix and Nushell

The image installs **Nix** from Fedora packages and **Nushell** from the pinned
upstream GitHub release tarball. Both are third-party components governed by
their own upstream licenses. This project's MIT license does **not** apply to
them.
