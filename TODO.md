# bluecat Live Project Status

This file is the living project status for coding agents and maintainers. Keep
it updated as work progresses. Permanent project rules belong in `AGENTS.md`,
not here.

Agents should read this file before starting non-trivial work and update it when
they complete meaningful changes or discover new project constraints.

## Current Goal

Build and maintain the `bluecat` bootc/rpm-ostree image and its netinstall ISO:

- Fedora Atomic/Kinoite-style base with `ID="bluecat"` preserved.
- NVIDIA support, extra desktop/gaming/admin packages, and Secure Boot MOK
  signing flow.
- A small Anaconda netinstall ISO that installs the pushed image from GHCR.
- Full user-facing ISO/Anaconda branding away from Fedora where this project can
  control it.
- Separate CI workflows for image and ISO artifacts.

## Recently Done

Package/image customization has been added in `container/image-setup.sh`:

- Common tools: FUSE, `htop`, `mc`, `dislocker`, `rclone`, `dnf5-plugins`,
  build/dev helpers, YubiKey/FIDO tools, PAM U2F, and SELinux policy tools.
- NVIDIA extras: `nvidia-modprobe`, `nvidia-settings`, and NVIDIA kernel args
  in `system_files/usr/lib/bootc/kargs.d/00-nvidia.toml`.
- Gaming stack: Steam, Lutris, MangoHud, Gamescope, vkBasalt, and Winetricks.
- Virtualization packages: QEMU/KVM, virt tools, libvirt, and Incus. Services are
  installed only and must not be enabled by default.
- Secure Boot first-boot UX: `bluecat-enroll-mok.service` prompts on tty1 before
  the display manager when Secure Boot is enabled, the bluecat MOK is not yet
  enrolled, and `/etc/pki/echocat/mok.der.ignore` is absent. It uses a
  `whiptail` dialog without text fallback and can queue `mokutil --import`, skip
  once, or create the ignore marker permanently for the installation. The
  one-time MokManager password is collected in the dialog and passed to
  `mokutil` via a temporary password-hash file.
- Scanner/mDNS packages: SANE backends, AirScan, IPP-over-USB, Avahi, and
  `nss-mdns`.
- `toolbox` is removed and `distrobox` is installed.
- Ghostty is installed via the `scottames/ghostty` COPR.
- Nushell uses the Gemfury repo with `gpgcheck=0` because the RPMs are unsigned.
- RustDesk is integrated via `RUSTDESK_VERSION` and release RPM download, with
  SELinux fcontext handling for bundled services.

Build task structure has been split:

- `mise build:image` builds the image rootless.
- `mise build:iso` builds the ISO and uses rootful podman only for the `mkksiso`
  step that needs loop devices.
- The old bare `mise build` task was replaced by `mise build:image`.

Netinstall ISO work is implemented:

- `iso/bluecat.ks.in` is intentionally minimal and interactive.
- The ISO installs `ghcr.io/echocat/bluecat:<ISO_IMAGE_TAG>` from the registry at
  install time.
- The default `ISO_IMAGE_TAG` follows the Fedora major version, for example
  `44`.
- The install uses `ostreecontainer --no-signature-verification`.
- The output is `output/bluecat-netinstall.iso` locally.

Full ISO/Anaconda branding is implemented:

- ISO volume ID is `bluecat-44`.
- GRUB menu titles use `bluecat`.
- GRUB `inst.stage2=hd:LABEL=...` references are verified to match the volume
  ID.
- Boot records are verified to remain valid after post-processing.
- `/Fedora-Legal-README.txt` is removed from the ISO root.
- `iso/README.iso.txt` is added to the ISO root.
- `iso/anaconda-branding/buildstamp.in` sets Anaconda product metadata to
  `bluecat`.
- `iso/anaconda-branding/anaconda-gtk.css` and the rendered sidebar logo brand
  the Anaconda UI.
- The Anaconda `product.img` is placed at `/images/product.img` inside the ISO.

CI workflow split is implemented:

- `.github/workflows/build.yaml` is now the `build:image` workflow.
- `.github/workflows/build-iso.yaml` is the `build:iso` workflow.
- `build:image` runs on every push to `main`, once per day, and for PRs labeled
  `test image`.
- `build:iso` runs on every push to `main` and once per week.
- Both workflows use concurrency cancellation so newer queued builds cancel
  older running builds on the same branch.
- ISO workflow publishes `output/bluecat-netinstall.iso` as the rolling release
  asset `bluecat.iso` and overwrites it every run.
- Image release pushes keep `latest`, the Fedora major tag such as `44`, and the
  existing timestamp format `44.<YYYYMMDDTHHMM>`.
- Timestamp-tag cleanup is implemented in `mise-tasks/push` with
  `RELEASE_TAG_RETENTION`, set to `3` in CI.
- PR push logic (`mise push pr <number>`) remains independent and unchanged.

## Key Decisions And Rationale

- Keep `ID="bluecat"`. Changing it to `ID=fedora` would make some tooling easier
  but would break the intended rebrand.
- Use Anaconda netinstall instead of `bootc-image-builder` for ISO creation.
  `bootc-image-builder` selects recipes from `os-release` and fails for the
  custom `bluecat` distro ID; Anaconda's `ostreecontainer` path does not have
  that limitation.
- Keep the ISO payload out of the ISO. The ISO remains small and installs the
  pushed image from the registry.
- Keep the Kickstart minimal. The installer should let users decide locale,
  keyboard, partitioning, LUKS, user creation, and similar choices.
- Keep `build:image` and `push` rootless because rootful podman had poor overlay
  performance in the observed environment.
- Use rootful podman only inside `build:iso` for `mkksiso`, because rootless
  containers could not attach loop devices even with privileged/device flags.
- Keep the existing timestamp tag format `44.<YYYYMMDDTHHMM>`. The user wrote
  `44-<TIMESTAMP>` once, but the existing repo behavior and docs used the dot
  format; this was intentionally not changed without an explicit migration.
- Do not broadly replace every `Fedora` string in ISO boot configs. A broad
  replacement corrupted the stage2 label once. Use targeted menu-title
  replacements and let `mkksiso -V` handle label consistency.

## Open / Next Steps

- Perform a real VM boot test of `output/bluecat-netinstall.iso` and visually
  verify the Anaconda title, sidebar logo, colors, and interactive installer
  flow.
- Observe the first real CI run of `.github/workflows/build-iso.yaml` to confirm
  the `rolling` release is created or updated and `bluecat.iso` is clobbered as
  intended.
- Observe the first real release image CI run to confirm GHCR timestamp-tag
  cleanup works with the repository/package permissions available to
  `GITHUB_TOKEN`.
- If the project ever wants timestamp tags in the `44-<TIMESTAMP>` format,
  migrate `mise-tasks/push`, cleanup matching, documentation, and any consumers
  together. Do not silently change the format.
- If Anaconda branding appears visually off in a VM, adjust the rendered logo
  size in `mise-tasks/build/iso` and/or CSS in `iso/anaconda-branding/`.

## Useful Verification Commands

Use these as appropriate for future changes:

```bash
bash -n mise-tasks/build/image mise-tasks/build/iso mise-tasks/push
mise exec -- shellcheck --external-sources --severity=warning mise-tasks/build/image mise-tasks/build/iso mise-tasks/push
mise exec -- yq '.name' .github/workflows/build.yaml .github/workflows/build-iso.yaml
mise tasks
mise lint
```

`mise-tasks/verify-keys` is a Deno script, not a shell script. Check it through
the project's Deno lint/check tasks, not ShellCheck.
