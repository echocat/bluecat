# Legal / licensing overview

This document explains how the different pieces that make up a `bluecat` image
relate to each other legally. It is **not** legal advice; it describes the
project's intent and the boundaries between the components.

## Component boundaries

| Component                      | Origin                                          | License / terms                        | Applies project (MIT) license? |
|--------------------------------|-------------------------------------------------|----------------------------------------|--------------------------------|
| Project source / config / docs | this repository (echocat)                       | MIT (see `LICENSE`)                    | Yes                            |
| Fedora base                    | Fedora Project (Kinoite base image)             | Fedora's licenses / trademarks         | No                             |
| RPM Fusion packages            | RPM Fusion (nonfree)                            | per-package (incl. proprietary NVIDIA) | No                             |
| NVIDIA driver components       | NVIDIA (via RPM Fusion)                         | NVIDIA proprietary license             | No                             |
| xone driver                    | medusalix/xone                                  | GPL-2.0                                | No                             |
| Microsoft Xbox firmware        | Microsoft (NOT shipped by this project)         | Microsoft terms                        | No                             |
| Flathub apps                   | third parties (NOT shipped, installed by users) | per-app (see each app on Flathub)      | No                             |
| Brave                          | Brave Software official RPM repository          | Brave / upstream terms                 | No                             |
| Gaming applications and tools  | Fedora, RPM Fusion and upstream projects        | per-package / upstream terms           | No                             |
| RustDesk                       | RustDesk upstream GitHub RPM release            | RustDesk / upstream terms              | No                             |
| Nix and Nushell                | Fedora packages and upstream releases           | per-component upstream licenses        | No                             |

## What this project does and does not do

- This project **does not redistribute** the Microsoft Xbox Wireless Adapter
  firmware. It is neither committed to the repository, nor bundled into the
  image, nor downloaded during the build. It can only be obtained locally on
  the target system after an explicit user action
  (see [`xbox-firmware.md`](xbox-firmware.md)).
- This project **does not modify** NVIDIA binaries.
- This project **does not claim** any official Fedora status. It is an
  **unofficial** Fedora-Atomic-based image and is **not affiliated with,
  endorsed by, or produced by the Fedora Project or Red Hat, Inc.**
- Users must comply with the terms of each third-party component
  (Fedora, RPM Fusion, NVIDIA, xone, Microsoft, Flathub apps, Brave, Steam,
  RustDesk, Nix, Nushell and other upstream packages) they use.

## Flatpak / Flathub

- This image enables the **Flathub** Flatpak repository (<https://flathub.org/>)
  system-wide on first boot, **unfiltered** (the full catalog, not the curated
  subset Fedora ships). The Flathub remote definition is added on first boot by
  `add-flathub.service`; nothing from Flathub is bundled into the image.
- Flathub hosts applications from **third parties**, including proprietary
  software. Each application carries its **own license and terms**; this project
  neither authors, redistributes, nor vets those applications. Users are
  responsible for complying with the terms of any app they install.
- The Fedora Flatpak remote (`registry.fedoraproject.org`) remains available but
  is deprioritized so that Flathub is preferred for applications available from
  both.

## Brave

- The default browser is **Brave**, installed from the official Brave RPM
  repository during image creation. RPM signatures are verified against Brave's
  RPM signing key before installation.
- Brave is a product of Brave Software, Inc. and is subject to its own license
  and terms; it is **not** covered by this project's MIT license.

## Other third-party applications and tools

- The image installs gaming-related software such as **Steam**, **Lutris**,
  MangoHud, Gamescope, vkBasalt and Winetricks. These components come from
  Fedora, RPM Fusion or their upstream projects and are governed by their own
  licenses and terms. Steam is proprietary Valve software.
- **RustDesk** is installed from the upstream GitHub RPM release and is governed
  by RustDesk's own upstream license and terms.
- **Nix** is installed from Fedora packages in multi-user daemon mode.
- **Nushell** is installed from the pinned upstream GitHub release tarball.

This project's MIT license does not apply to those third-party components.

## Fedora trademarks (Remix note)

This image combines unmodified Fedora software with non-Fedora software
(NVIDIA from RPM Fusion, the xone driver). Per the Fedora trademark guidelines:

- The Fedora branding packages (`fedora-logos`, `fedora-release`,
  `fedora-release-notes`) are removed/replaced so the image does not carry
  Fedora trademarks. `os-release` is rewritten to identify the system as
  `bluecat` (see `image/setup/stage2.d/800-rebranding`).
- The software provided here is **not** provided or supported by the Fedora
  Project.
- Official, unmodified Fedora software is available from the Fedora Project at
  <https://fedoraproject.org/>.

Fedora and the Infinity design logo are trademarks of Red Hat, Inc. This
project uses the word "Fedora" only descriptively to identify the upstream
software it is based on.

## No warranty

The image and this project are provided "as is", without warranty of any kind,
as stated in `LICENSE`. This project makes no guarantees regarding the
third-party components it integrates.
