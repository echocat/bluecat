# NVIDIA components

`bluecat` images built with the NVIDIA variant contain **proprietary NVIDIA
driver components**.

## What is included and where it comes from

The NVIDIA driver is obtained from **RPM Fusion (nonfree)**
(<https://rpmfusion.org/>), not from Fedora and not from NVIDIA directly:

- **Kernel module** — built from the `akmod-nvidia` source package during the
  container build (stage 1, `image/setup/stage1.d/200-nvidia-akmod`) and signed
  with the local MOK for Secure Boot.
- **Userspace** — installed in stage 2 (`image/setup/stage2.d/110-nvidia-packages`):
  - `xorg-x11-drv-nvidia`
  - `xorg-x11-drv-nvidia-cuda`
  - `libva-nvidia-driver`

## Licensing

- The NVIDIA driver is **proprietary**. NVIDIA components are subject to
  **NVIDIA's own license terms**, which apply in addition to everything else.
- This project's MIT license (`LICENSE`) does **not** apply to NVIDIA
  components.
- This project does **not** modify NVIDIA binaries. The kernel module is
  compiled from the RPM Fusion source package and only **signed** (its contents
  are not altered); the userspace packages are installed unmodified.
- If RPM Fusion ships license files with these packages, they are installed by
  the packages themselves and can be found on the running system under
  `/usr/share/doc/` and `/usr/share/licenses/` of the respective package.

## Determining the exact version in use

The concrete NVIDIA version depends on what RPM Fusion ships at build time
(builds use `--no-cache` and always pull current packages). To inspect what a
given image actually contains, on the running system:

```bash
# installed NVIDIA-related packages + versions
rpm -qa | grep -i nvidia

# the running kernel module version
modinfo nvidia | grep -E '^(version|vermagic|filename)'

# generate a package list (poor-man's SBOM) for auditing
rpm -qa --qf '%{NAME} %{VERSION}-%{RELEASE} %{LICENSE}\n' | sort
```

> Note: because RPM Fusion updates over time, two images built on different
> days can contain different NVIDIA versions even from the same source tree.
