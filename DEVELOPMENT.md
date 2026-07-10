# bluecat's Development documentation

## Layout

```
.
├── mise.toml                # mise config (tools + task discovery)
├── mise-tasks/              # self-contained file-tasks -> `mise <name>`
│   ├── build/               # mise build:image (local image build) + build:iso (offline installer ISO)
│   ├── publish/             # mise publish:image/publish:iso
│   ├── keys                 # mise keys         (generate MOK + Cosign keys)
│   ├── verify-keys          # mise verify-keys  (validate MOK, Deno/TS)
│   ├── branding             # mise branding     (render logo assets, Deno/TS)
│   ├── syntax               # mise syntax
│   └── lint/                # mise lint (+ lint:shell/deno/container/workflows/legal)
├── Containerfile            # 2-stage bootc build
├── certs/                   # public cert (mok.der/crt); mok.key = private!
├── dependencies.yaml        # pinned versions of dependencies
├── image/setup/             # scripts that run INSIDE the image build
│   ├── stage1               # stage 1: runs numbered stage1.d scripts
│   ├── stage1.d/            # stage 1 setup steps, ordered by filename
│   ├── stage2               # stage 2: runs numbered stage2.d scripts
│   └── stage2.d/            # stage 2 setup steps, ordered by filename
├── iso/                     # offline installer ISO Kickstart, rootfs and product.img branding
├── assets/branding/         # echocat branding sources + `mise branding`
├── docs/                    # legal / NVIDIA / Xbox-firmware documentation
├── LICENSE                  # MIT (project's own files only)
├── NOTICE.md                # third-party attributions
└── image/rootfs/            # files copied verbatim into the image (/)
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
2. Have [skopeo](https://github.com/containers/skopeo) installed:
   ```shell
   # Ubuntu/Debian
   sudo apt install -y skopeo
   # Fedora/Red Hat/CentOS
   sudo dnf install -y skopeo
   ```
3. Have [mise](https://mise.jdx.dev/) installed (will ensure all other required tools are present):
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
4. Build the rolling offline installer ISO:
   Uses Fedora's Anaconda boot ISO plus `mkksiso` to embed a Kickstart and the
   locally built bootc image as `/images/bluecat.oci`. The initial
   deployment is offline; the installed system records the release image ref for
   later updates.
   ```shell
   mise build:iso
   # output/bluecat.iso, output/bluecat.iso.sha256 and output/bluecat.iso.md5 are created
   ```
5. Publish the rolling ISO to S3-compatible storage:
   ```shell
   mise publish:iso
   # https://download.bluecat.echocat.org/latest/bluecat.iso
   ```

6. Test image publishing/signing without touching release tags:
   ```shell
   mise publish:image test local
   # pushes test-local-<UTC-timestamp>, test-local, sha256-<digest>.sig,
   # and test-local-<UTC-timestamp>.sig
   ```


## CI (GitHub Actions)

`.github/workflows/build.yaml` builds the image, decides what to push and, for
release builds, publishes the rolling ISO:

| Trigger                        | Action                                        |
|--------------------------------|-----------------------------------------------|
| push to `main`                 | build image + build ISO + `mise publish:image release` + ISO publish |
| schedule on `main`             | build image + build ISO + `mise publish:image release` + ISO publish |
| PR labeled `test image`        | build image + build ISO + `mise publish:image pr <number>` |
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

For release builds, the workflow builds the rolling offline installer ISO before any
image tag is published. Only after both local artifacts build successfully does it
run `mise publish:image release`, followed by the ISO upload. It uploads
`bluecat.iso`, `bluecat.iso.sha256` and `bluecat.iso.md5` to the configured
S3-compatible bucket/prefix. The public URL is:

<https://download.bluecat.echocat.org/latest/bluecat.iso>

Required ISO upload secrets:

| Secret                 | Content                         |
|------------------------|---------------------------------|
| `ISO_S3_ACCESS_KEY_ID`     | S3/R2 access key                |
| `ISO_S3_SECRET_ACCESS_KEY` | S3/R2 secret access key         |

`.github/workflows/lint.yaml` runs `mise lint` (ShellCheck, Deno checks,
hadolint, workflow YAML) without secrets — safe for PRs.
