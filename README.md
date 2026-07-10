# bluecat — unofficial Fedora Atomic based desktop image

`bluecat` is an **unofficial** desktop image built from **Fedora** software
(Fedora Atomic Desktop / Kinoite, KDE) based on **bootc / OCI**.

> [!NOTE]
> **Not affiliated with, endorsed by, or produced by the Fedora Project or
> Red Hat, Inc.** The word "Fedora" is used only descriptively to identify the
> upstream software this image is built from. Official, unmodified Fedora
> software is available from the [Fedora Project](https://fedoraproject.org/).

#### Included

- **NVIDIA drivers** from RPM Fusion (nonfree), kernel modules pre-compiled.
  These are **proprietary** NVIDIA components subject to NVIDIA's own license
  terms (see [`docs/nvidia.md`](docs/nvidia.md)); this project's license does
  not apply to them.
- [**xone** (Xbox controller driver)](https://github.com/medusalix/xone). The
  proprietary Microsoft Xbox Wireless Adapter firmware is **not** included and
  is only fetched locally, after an explicit user action
  (see [`docs/xbox-firmware.md`](docs/xbox-firmware.md)).
- [**Nix** package manager](https://nixos.org/) in multi-user daemon mode.
- **Secure Boot**: all out-of-tree modules are signed with a **local MOK**;
  the public cert is enrolled into the firmware once
- sensible desktop defaults (codecs, VA-API, etc.)

> This image is not fully open source: it may contain proprietary NVIDIA
> driver components. See [`NOTICE.md`](NOTICE.md) and
> [`docs/legal.md`](docs/legal.md) for the licensing breakdown.

> [!IMPORTANT] 
> This repo contains **only** source code, config, build
> recipes, docs and scripts. **No** images, OSTree commits, ISO/OCI/RPM,
> firmware or private keys are committed.

### Image tags

`mise build:image` always builds the fixed local tag `:local` and never pushes it.
`mise publish:image` re-tags that image and pushes:

| mode              | tags pushed                                             |
|-------------------|---------------------------------------------------------|
| `release`         | `<major>.<YYYYMMDD>T<HHmm>` (UTC), `<major>`, `latest`  |
| `pr <number>`     | `pr-<number>` (only)                                    |

In CI this is decided automatically (see below): push to `main` → `release`,
a PR labeled `test image` → `pr <number>`.

The tasks are self-contained file-tasks in `mise-tasks/` (they contain the
full logic, no separate wrapper scripts). All versions/names are centralized in
`build.env`. The scripts that run *inside* the image build live in
`image/setup/`.

### Rolling ISO

The rolling offline installer ISO is published here:

- ISO: <https://download.bluecat.echocat.org/latest/bluecat.iso>
- SHA256: <https://download.bluecat.echocat.org/latest/bluecat.iso.sha256>
- MD5: <https://download.bluecat.echocat.org/latest/bluecat.iso.md5>

---

## Secure Boot — procedure

For the self-signed modules to load under active Secure Boot, the **public**
MOK cert must be enrolled into the firmware once. bluecat prompts for this early
in boot when Secure Boot is enabled, the key is not enrolled yet, and
`/etc/pki/echocat/mok.der.ignore` does not exist. The prompt uses a `whiptail`
dialog on `/dev/tty9` before the display manager starts. If `whiptail` is
unavailable, the prompt is skipped as an error instead of falling back to plain
text.

The boot prompt offers three choices:

1. register the key now and reboot into MokManager
2. skip for this boot
3. skip forever on this installation by creating
   `/etc/pki/echocat/mok.der.ignore`

When registering, bluecat asks for the one-time MokManager password in the
`whiptail` dialog and passes a generated password hash to `mokutil`; `mokutil`
does not prompt for the password itself.

If skipped, NVIDIA-only systems can fail to reach a graphical login because
`nouveau` is disabled and Secure Boot rejects the unsigned-by-firmware NVIDIA
module until the MOK is enrolled.

### Manual fallback: queue the public cert for enrollment

On the target system (after installation `mok.der` lives at
`/etc/pki/echocat/mok.der`, or use the file from `certs/`):

```bash
sudo mokutil --import /etc/pki/echocat/mok.der
```

`mokutil` asks for a **one-time password** — remember it, it is requested on
the next reboot.

### Reboot -> MOK Manager (blue shim screen)

On the next boot **MokManager** appears:

1. select *Enroll MOK*
2. *Continue* -> *Yes*
3. enter the password set in step 1
4. reboot

### Verify

```bash
mokutil --list-enrolled | grep -i "bluecat"
# and after boot:
modinfo nvidia | grep -i sig
modinfo xone-gip | grep -i sig
```

> If the signing key is **regenerated**, repeat this procedure with the new
> cert.

---

## Install / switch (rebase)

On an existing Fedora Atomic system (Kinoite):

```bash
curl -fsSL https://raw.githubusercontent.com/echocat/bluecat/main/scripts/rebase-signed | sudo bash
sudo systemctl reboot
```

This installs the bluecat Cosign trust policy locally and rebases directly with
`ostree-image-signed:registry:ghcr.io/echocat/bluecat:44`. Published images are
signed with Cosign v3 using `--use-signing-config=false` and
`--new-bundle-format=false` until rpm-ostree can verify Cosign's new bundle
format natively.

or (bootc-native, on bootc systems):

```bash
sudo bootc switch ghcr.io/echocat/bluecat:44
sudo systemctl reboot
```

The NVIDIA/xone modules only load under active Secure Boot **after** a
successful MOK enrollment (see above).

> **Boot splash / LUKS branding:** the boot splash and the LUKS unlock prompt
> are rendered from the *initramfs*, not from `/usr`. The image build rebuilds
> the shipped initramfs after applying the bluecat Plymouth assets, explicitly
> keeping dracut's OSTree module enabled. A **fresh ISO install** therefore
> shows the bluecat splash on first boot. When **rebasing onto an existing
> Fedora system**, the old initramfs may be kept until it is regenerated; run
> `sudo rpm-ostree initramfs --enable` to rebuild it from the bluecat
> deployment. The running system (KDE "About", shutdown splash) is branded
> regardless.

---

## xone firmware (proprietary, not in the image)

The xone **driver** is included; the Microsoft wireless dongle **firmware** is
proprietary and is **not** shipped, **not** bundled and **not** downloaded
during the build. The image ships only a local opt-in activator. On the target
system (only needed for the USB wireless dongle, not for wired/Bluetooth):

```bash
sudo enable-xone-firmware
```

The same flow is available from the desktop application menu as **Enable Xbox
Wireless Adapter Firmware**; that launcher requests root privileges via
`pkexec` and runs the activator in a terminal.

This shows a disclaimer and requires explicit confirmation through a `whiptail`
dialog, with a text fallback that requires typing exactly `yes`; only then does
it set up a local systemd unit that downloads the firmware from Microsoft and
verifies the extracted firmware against a pinned SHA256 hash. See
[`docs/xbox-firmware.md`](docs/xbox-firmware.md) for the full flow and how to
undo it.

---

## License & legal

The files in this repository authored by this project are licensed under the
**MIT** license (see [`LICENSE`](LICENSE)). This license applies **only** to
the project's own files — **not** to any third-party software integrated at
build time or shipped in the image (Fedora base, RPM Fusion packages, the
proprietary NVIDIA driver, the xone driver, or the Microsoft firmware).

See:

- [`NOTICE.md`](NOTICE.md) — third-party attributions
- [`docs/legal.md`](docs/legal.md) — component/licensing boundaries
- [`docs/nvidia.md`](docs/nvidia.md) — proprietary NVIDIA components
- [`docs/xbox-firmware.md`](docs/xbox-firmware.md) — Xbox firmware (opt-in)

---

## More topics
- [Development](DEVELOPMENT.md)
- [Third-party attributions](NOTICE.md)
