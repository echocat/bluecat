# bluecat Project Instructions

This file contains durable project rules for coding agents. It should stay
stable and focused on conventions, invariants, commands, and project-specific
gotchas.

## Current Work And Live Status

CRITICAL: For current in-progress work, recent changes, decisions, and open
tasks, read `@TODO.md` using your Read tool before making non-trivial changes.
Treat `TODO.md` as the live project status and keep it updated as work
progresses.

`TODO.md` is not the place for permanent rules. Durable project rules belong in
this file.

## Project Overview

`bluecat` is a rebranded Fedora Atomic/Kinoite-style bootc/rpm-ostree image.
The image intentionally uses `ID="bluecat"` in `/usr/lib/os-release` while
retaining Fedora compatibility through `ID_LIKE=fedora`.

The project builds:

- An OCI image published to GHCR.
- A small Anaconda netinstall ISO that installs the pushed image from the
  registry via `ostreecontainer`.
- Branding assets and installer/ISO rebranding so user-facing Fedora branding is
  removed where this project controls it.

## Build And Verification Commands

Use `mise` tasks as the public project interface:

- `mise build:image` builds the local OCI image.
- `mise push release` pushes release tags for `main` builds.
- `mise push pr <number>` pushes the PR test image tag only.
- `mise build:iso` builds the netinstall ISO.
- `mise verify-keys` validates Secure Boot MOK signing material.
- `mise lint` runs the full static verification suite.
- `mise tasks` lists available tasks.

Before marking shell/workflow changes done, run the relevant checks:

- `bash -n` for Bash tasks.
- `shellcheck --external-sources --severity=warning` for Bash tasks only.
- Do not run ShellCheck on `mise-tasks/verify-keys`; it is a Deno script.
- Validate workflow YAML with the existing workflow lint task or `yq`.
- Prefer `mise lint` for the final project-level verification when feasible.

## Hard Rules

- Keep `ID="bluecat"` in `/usr/lib/os-release`. Do not change it to
  `ID=fedora` to make tools happy.
- The ISO is a netinstall ISO. Do not bake the OS payload into it unless the
  project explicitly changes direction.
- Keep the Kickstart minimal and interactive. It should activate networking and
  point Anaconda at the image with `ostreecontainer`. Let Anaconda use its normal
  UI/default completion flow; do not force graphical mode or automatic reboot.
  Do not add partitioning, user creation, LUKS, locale, or keyboard choices
  unless explicitly requested.
- The image install currently uses `ostreecontainer --no-signature-verification`.
  This means TLS transport only, not container signature verification.
- `build:image` and `push` run rootless for performance. Do not switch them to
  rootful without re-evaluating overlay performance.
- `build:iso` starts as the normal user but uses rootful podman internally for
  the `mkksiso` step because loop devices are required.
- Do not enable `libvirt` or `incus` services by default. They are installed
  only.
- `toolbox` is removed and `distrobox` is installed.
- The Nushell Gemfury repo uses `gpgcheck=0` because the RPMs are unsigned.
- Keep changes surgical. Do not refactor adjacent code or documentation unless
  it is directly required by the task.

## CI Model

The workflows are intentionally split by artifact:

- `.github/workflows/build.yaml` is the `build:image` workflow.
- `.github/workflows/build-iso.yaml` is the `build:iso` workflow.

`build:image` runs:

- On every push to `main`.
- Once per day from `main`.
- For PRs only when the `test image` label is applied.

For release builds it pushes:

- `latest`
- the Fedora major tag, for example `44`
- a timestamp tag in the existing format `44.<YYYYMMDDTHHMM>`

Timestamp-tag retention is controlled with `RELEASE_TAG_RETENTION` and is set to
`3` in CI. PR image push behavior must remain independent from this cleanup.

`build:iso` runs:

- On every push to `main`.
- Once per week from `main`.

It publishes the rolling release asset as `bluecat.iso` under the `rolling`
GitHub release and overwrites that asset on each run.

Both artifact workflows use concurrency cancellation so a newer queued run on
the same branch cancels an older running one.

## ISO And Anaconda Gotchas

- `bootc-image-builder` is not used for the ISO path because it selects build
  recipes from `os-release` and does not know the `bluecat` distro ID.
- Anaconda's `ostreecontainer` path works with `ID="bluecat"`, so the netinstall
  ISO keeps the rebrand intact.
- `mkksiso -a` maps every added path to `os.path.basename(path)` at the ISO
  root. It does not support `SRC=DEST` syntax.
- Files that should land in the ISO root live under `iso/rootfs/`. Because
  `mkksiso -a` maps every added path to `os.path.basename(path)`, pass the
  top-level entries from `iso/rootfs/` rather than the directory itself.
- Files that should land inside Anaconda's `product.img` live under
  `iso/product.img/`. The ISO build may package them into a
  temporary `/images/product.img`, but `product.img` itself is a build artifact
  and should not be committed.
- `mkksiso -V` sets the ISO volume ID and rewrites GRUB stage2/LABEL references
  to match. Do not run broad replacements like `-R "Fedora" "bluecat"` after
  that, because it can corrupt `inst.stage2=hd:LABEL=...` and make the ISO fail
  to boot.
- Only replace human-readable GRUB menu strings with targeted `-R` rules.

## Key Files

- `Containerfile` - image build stages and build arguments.
- `container/image-setup.sh` - package installation, OS rebranding, and most
  image customization.
- `build.env` - central build variables. Treat it carefully; it may be protected
  by local read rules.
- `mise-tasks/build/image` - rootless local image build.
- `mise-tasks/build/iso` - Anaconda netinstall ISO build and ISO/installer
  branding.
- `mise-tasks/push` - release and PR tag/push logic plus release timestamp tag
  retention.
- `mise-tasks/verify-keys` - Deno-based MOK key/cert validation.
- `.github/workflows/build.yaml` - image CI workflow.
- `.github/workflows/build-iso.yaml` - ISO CI workflow and rolling release asset
  upload.
- `iso/bluecat.ks.in` - minimal Kickstart template.
- `iso/product.img/` - bare Anaconda product image branding files.
- `iso/rootfs/` - files added to the ISO root, including `/README.txt`.
- `system_files/` - files copied into the final image.
- `system_files/usr/lib/bootc/kargs.d/00-nvidia.toml` - NVIDIA-related bootc
  kernel arguments.

## Environment Notes

- Development may happen under WSL2 even when the user's primary environment is
  Windows. Be careful when discussing paths; prefer relative repo paths.
