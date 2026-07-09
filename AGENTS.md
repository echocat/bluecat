# bluecat Project Instructions

This file contains durable project rules for coding agents. It should stay
stable and focused on conventions, invariants, commands, and project-specific
gotchas.

## Project Overview

`bluecat` is a rebranded Fedora Atomic/Kinoite-style bootc/rpm-ostree image.
The image intentionally uses `ID="bluecat"` in `/usr/lib/os-release` while
retaining Fedora compatibility through `ID_LIKE=fedora`.

The project builds:

- An OCI image published to GHCR.
- An offline Anaconda installer ISO that embeds the locally built OCI image
  payload as `/images/bluecat.oci`.
- Branding assets and installer/ISO rebranding so user-facing Fedora branding is
  removed where this project controls it.

## Build And Verification Commands

Use `mise` tasks as the public project interface:

- `mise build:image` builds the local OCI image.
- `mise publish:image release` pushes release tags for `main` builds.
- `mise publish:image pr <number>` pushes the PR test image tag only.
- `mise build:iso` builds the offline installer ISO.
- `mise publish:iso` uploads `bluecat.iso`, `bluecat.iso.sha256`, and
  `bluecat.iso.md5` to S3-compatible storage.
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
- The ISO is an offline Anaconda installer ISO. It embeds the local bootc image
  as an OCI layout and installs it with Anaconda's `bootc` Kickstart command.
  Do not switch back to Titanoboa unless the project explicitly changes
  direction.
- `build:image` and `publish:image` run rootless for performance. Do not switch
  them to rootful without re-evaluating overlay performance.
- `build:iso` starts as the normal user but uses rootful podman internally for
  the `mkksiso` step because loop devices are required.
- Do not enable `libvirt` or `incus` services by default. They are installed
  only.
- `toolbox` is removed and `distrobox` is installed.
- The Nushell Gemfury repo uses `gpgcheck=0` because the RPMs are unsigned.
- Keep changes surgical. Do not refactor adjacent code or documentation unless
  it is directly required by the task.

## CI Model

`.github/workflows/build.yaml` is the artifact workflow. It builds the OCI image
and the ISO locally first, then publishes artifacts only after both builds
succeeded.

The artifact workflow runs:

- On every push to `main`.
- Once per day from `main`.
- For PRs only when the `test image` label is applied.

For release builds it pushes:

- `latest`
- the Fedora major tag, for example `44`
- a timestamp tag in the existing format `44.<YYYYMMDDTHHMM>`

Timestamp-tag retention is controlled with `RELEASE_TAG_RETENTION` and is set to
`3` in CI. PR image push behavior must remain independent from this cleanup.

For release builds, `build:iso` runs before `publish:image release`, so a broken
ISO build prevents publishing the release image tags. The workflow then runs
`publish:image release` and finally `publish:iso`. PR test image builds also run
the local ISO build as a gate, but do not publish the ISO. `publish:iso` uploads
`bluecat.iso`, `bluecat.iso.sha256`, and `bluecat.iso.md5` to the configured
S3-compatible storage under `s3://bluecat/latest/`. The public ISO URL is
`https://download.bluecat.echocat.org/latest/bluecat.iso`. GitHub Releases are
not used for ISO publishing.

The workflow uses concurrency cancellation so a newer queued run on the same
branch cancels an older running one.

## ISO And Anaconda Gotchas

- `mise build:iso` exports the local `:local` image as
  `output/bluecat.oci` and embeds it under `/images/bluecat.oci` in the ISO.
- `iso/bluecat.ks.in` uses Anaconda's `bootc` Kickstart command with
  `oci:/run/install/repo/images/bluecat.oci:bluecat:local` as source and the
  configured release image ref as update target.
- Files that should land in the ISO root live under `iso/rootfs/`. Files that
  should land inside Anaconda's temporary `product.img` live under
  `iso/product.img/` and are packaged during `mise build:iso`.
- `mkksiso -V` sets the ISO volume ID and rewrites GRUB stage2/LABEL references
  to match. Do not run broad replacements like `-R "Fedora" "bluecat"`; only
  replace human-readable GRUB menu strings with targeted `-R` rules.
- ISO publication uses generic S3 variable names (`ISO_S3_BUCKET`, `ISO_S3_PREFIX`,
  `ISO_S3_ENDPOINT_URL`) even though the current backend is Cloudflare R2.

## Key Files

- `Containerfile` - image build stages and build arguments.
- `image/setup/image-setup.sh` - package installation, OS rebranding,
  and most image customization.
- `iso/bluecat.ks.in` - offline bootc Kickstart template.
- `iso/rootfs/` - files added to the ISO root.
- `iso/product.img/` - Anaconda product image branding files.
- `build.env` - central build variables. Treat it carefully; it may be protected
  by local read rules.
- `mise-tasks/build/image` - rootless local image build.
- `mise-tasks/build/iso` - offline Anaconda installer ISO build.
- `mise-tasks/publish/image` - release and PR tag/push logic plus release timestamp tag
  retention.
- `mise-tasks/publish/iso` - S3-compatible rolling ISO upload.
- `mise-tasks/verify-keys` - Deno-based MOK key/cert validation.
- `.github/workflows/build.yaml` - OCI image CI workflow plus release ISO build
  and S3-compatible rolling ISO upload.
- `image/rootfs/` - files copied into the final image.
- `image/rootfs/usr/lib/bootc/kargs.d/00-nvidia.toml` - NVIDIA-related bootc
  kernel arguments.

## Environment Notes

- Development may happen under WSL2 even when the user's primary environment is
  Windows. Be careful when discussing paths; prefer relative repo paths.
