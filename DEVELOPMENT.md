# bluecat's Development documentation

## Layout

```
.
├── mise.toml                # mise config (tools + task discovery)
├── mise-tasks/              # self-contained file-tasks -> `mise <name>`
│   ├── build/               # mise build:image (local image build) + build:iso (offline installer ISO)
│   ├── keys                 # mise keys         (generate MOK + Cosign keys)
│   ├── verify-keys          # mise verify-keys  (validate MOK, Deno/TS)
│   ├── push                 # mise push         (push to registry, bash)
│   ├── branding             # mise branding     (render logo assets, Deno/TS)
│   ├── syntax               # mise syntax
│   └── lint/                # mise lint (+ lint:shell/deno/container/workflows/legal)
├── build.env                # central variables (version, registry, xone ref)
├── Containerfile            # 2-stage bootc build
├── certs/                   # public cert (mok.der/crt); mok.key = private!
├── container/               # scripts that run INSIDE the container build
│   ├── build-modules.sh     # stage 1: build + sign modules
│   └── image-setup.sh       # stage 2: runtime + defaults + rebrand
├── assets/branding/         # echocat branding sources + `mise branding`
├── docs/                    # legal / NVIDIA / Xbox-firmware documentation
├── LICENSE                  # MIT (project's own files only)
├── NOTICE.md                # third-party attributions
└── system_files/            # files copied verbatim into the image (/)
    └── usr/bin/enable-xone-firmware  # local opt-in Xbox firmware activator
```

## Architecture

Two-stage container build (`Containerfile`):

1. **builder** — compiles NVIDIA (akmod) + xone against the kernel of the base
   image and **signs** the modules with the MOK.
2. **final** — `FROM kinoite:44`, takes over the signed modules, installs the
   NVIDIA userspace + defaults, ships the **public** cert.

The result is a bootc image that an existing Kinoite system is switched to via
`bootc switch` / `rpm-ostree rebase`.

## Prerequisites

1. Have [Podman](https://podman.io/) installed:
   ```shell
   # Ubuntu/Debian
   sudo apt install -y podman
   # Fedora/Red Hat/CentOS
   sudo dnf install -y podman
   ```
2. Have [mise](https://mise.jdx.dev/) installed (will ensure all other required tools are present):
   ```shell
   curl https://mise.run | sh
   ```

---

## Build targets

> [!NOTE]
> Tasks are self-contained mise file-tasks in `mise-tasks/`; run `mise tasks` for the full list.

1. Ensure `./.env` file are present:
   ```text
   COSIGN_PASSWORD=<the password>
   ```
2. Ensure keys are present:
   ```shell
   mise keys
   ```
3. Build the image (always built as the fixed local tag `:local`, never pushed)
   Every build is fully up-to-date: the upstream base image is re-pulled if
   newer (`--pull=newer`) and no layer cache is reused (`--no-cache`), so the
   latest RPMs (RPM Fusion, NVIDIA, kernel-devel) are fetched every time.
   Runs rootless (fast native overlay diff); image lands in the user storage.
   ```shell
   mise build:image
   # ghcr.io/echocat/bluecat:local is created in podman
   ```
4. Build a small network-install ISO:
   Uses Anaconda + an embedded Kickstart (NOT `bootc-image-builder`, which
   rejects our rebranded `ID="bluecat"`). The ISO does NOT embed the OS
   payload: it installs the image from the registry at install time, so it
   stays small and valid across image changes. It is fully rebranded away
   from Fedora (volume id, GRUB menu, [iso/rootfs/](iso/rootfs) docs and the Anaconda
   installer title/logo via a temporary `product.img` built from bare files in
   [iso/product.img/](iso/product.img)).
   **requires** the image to be pushed (step 3) under `ISO_IMAGE_TAG` (default the
   Fedora major, e.g. `44`) and the registry reachable at install time.
   ```shell
   mise build:iso
   # output/bluecat-netinstall.iso is created
   ```


## CI (GitHub Actions)

`.github/workflows/build.yaml` builds the image and decides what to push:

| Trigger                        | Action                                        |
|--------------------------------|-----------------------------------------------|
| push to `main`                 | build + `mise push release`                   |
| PR labeled `test image`        | build + `mise push pr <number>`               |
| other branches / events        | (not triggered) — build locally, no push      |

The PR path only fires when the `test image` label is **added** to a PR
(`labeled` event); other labels do not trigger an image build.

The image is pushed to **ghcr.io/echocat/bluecat**. Authentication uses the
automatic `GITHUB_TOKEN` (the workflow grants it `packages: write`), so no
registry credentials need to be stored. Only the signing material is needed as
secrets:

| Secret            | Content                                  |
|-------------------|------------------------------------------|
| `MOK_KEY`         | content of `certs/mok.key` (private)     |
| `MOK_CRT`         | content of `certs/mok.crt`               |
| `MOK_DER_B64`     | `base64 -w0 certs/mok.der`               |
| `COSIGN_KEY`      | content of `certs/cosign.key` (private)  |
| `COSIGN_PUB`      | content of `certs/cosign.pub`            |
| `COSIGN_PASSWORD` | password used for `certs/cosign.key`     |

`.github/workflows/lint.yaml` runs `mise lint` (ShellCheck, Deno checks,
hadolint, workflow YAML) without secrets — safe for PRs.

