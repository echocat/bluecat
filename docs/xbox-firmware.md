# Xbox Wireless Adapter firmware

`bluecat` includes the **xone** driver (the open-source Xbox controller driver,
<https://github.com/medusalix/xone>). It does **not** include the proprietary
**Microsoft Xbox Wireless Adapter firmware**.

## What is and is not shipped

The public image contains **only**:

- the xone driver (compiled from source during the build), and
- `/usr/bin/enable-xone-firmware` — a local opt-in activator.

The image does **NOT** contain:

- the Microsoft firmware (`xow_dongle.bin`),
- a pre-enabled systemd unit,
- any pre-created firmware files,
- any firmware download during the build.

The firmware is proprietary Microsoft software, subject to Microsoft's terms.
This project only provides the local activation mechanism; it neither ships nor
redistributes the firmware.

## Activating the firmware (local, explicit opt-in)

The firmware is only needed for the **USB wireless dongle** — not for wired
controllers or Bluetooth. On the target system, run:

```bash
sudo enable-xone-firmware
```

Alternatively, launch **Enable Xbox Wireless Adapter Firmware** from the desktop
application menu. The launcher uses `pkexec` to request root privileges and runs
the same activator in a terminal.

The activator:

1. Requires root and checks the required tools
   (`systemctl`, `curl`, `sha256sum`, `mktemp`, `install`, `cabextract`).
2. Prints a clear disclaimer and links to Microsoft's terms of use and the
    xone project.
3. Requires explicit confirmation through a `whiptail` dialog. If `whiptail`
    cannot be used, it falls back to typing exactly `yes`. **The default is to
    abort** — if you do not confirm, **nothing is created and nothing is
    downloaded.**

Only **after** you confirm, it creates locally:

- `/etc/acknowledgements/microsoft-xbox-controller-firmware` — records your
  explicit consent (the systemd unit refuses to run without it).
- `/var/lib/xone-firmware/bin/fetch` — the fetch script.
- `/var/lib/xone-firmware/firmware/` — the writable firmware directory.
- `/etc/systemd/system/xone-firmware-fetch.service` — a oneshot unit.

It then runs `systemctl daemon-reload` and
`systemctl enable --now xone-firmware-fetch.service`.

## How the fetch works

The generated fetch script (`/var/lib/xone-firmware/bin/fetch`):

- re-checks that the acknowledgement file exists (otherwise it refuses to run),
- only downloads the firmware if it is not already present,
- only downloads from the pinned Microsoft / Windows Update URL,
- verifies the extracted firmware against a pinned **SHA256** hash and **aborts on
  mismatch**,
- installs the firmware to `/var/lib/xone-firmware/firmware/xow_dongle.bin`,
- points the kernel firmware loader at that directory when possible by writing
  the path to `/sys/module/firmware_class/parameters/path` (this avoids writing
  into the read-only `/usr/lib/firmware` of an immutable/bootc system),
- tells you to re-plug the dongle or reboot afterwards.

The download happens **from your machine**, not from this project's
infrastructure, and only after you opted in.

## Undoing the activation

To disable and remove the local firmware setup:

```bash
sudo systemctl disable --now xone-firmware-fetch.service
sudo rm -f /etc/systemd/system/xone-firmware-fetch.service
sudo systemctl daemon-reload
sudo rm -rf /var/lib/xone-firmware
sudo rm -f /etc/acknowledgements/microsoft-xbox-controller-firmware
```

## License note

The downloaded firmware is Microsoft's proprietary software and is governed by
Microsoft's terms of use. This project neither redistributes it nor grants any
rights to it; it only automates a local download that you initiate.
