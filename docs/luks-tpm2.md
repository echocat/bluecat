# TPM2 disk unlock

bluecat includes a local TPM2 unlock manager for systems with existing LUKS2
encrypted devices.

The tool does not create disk encryption. It reads LUKS2 devices from
`/etc/crypttab` and adds or removes TPM2 unlock tokens for those devices. The
normal LUKS passphrase remains enrolled as the recovery fallback.

## Requirements

- At least one LUKS2 device.
- A TPM2 device, usually `/dev/tpmrm0`.
- `systemd-cryptenroll` and matching systemd unlock support in the initramfs.
- Existing LUKS passphrase for enrollment.

## Using the desktop launcher

Open **Manage LUKS TPM** from the application menu.

The launcher requests administrator privileges with `pkexec` and runs in a
terminal. It uses `whiptail` for the prompts when available and falls back to
plain terminal prompts otherwise.

## Using the command line

Run:

```bash
sudo manage-luks-tpm
```

The tool reads LUKS2 devices listed in `/etc/crypttab`.

If no matching LUKS2 volume is found, it shows an informational dialog and exits.
If exactly one volume is found, it opens that volume directly. If more than one
volume is found, it first shows a numbered selection menu and then opens the
selected volume.

For each volume, the dialog shows the device path, LUKS2 UUID, detected usage
such as root filesystem or swap when available, and the current TPM2 state. If
TPM2 unlock is disabled, the dialog asks for the current LUKS passphrase and can
activate TPM2 unlock for that volume. If TPM2 unlock is already enabled, the
dialog can deactivate it for that volume.

The device list is built from `/etc/crypttab`. Duplicate entries are removed.

## What enabling does

When enabling TPM2 unlock, the tool:

- asks for the current LUKS passphrase for the selected device,
- passes the passphrase to `systemd-cryptenroll` as the
  `cryptenroll.passphrase` systemd credential,
- asks `systemd-cryptenroll` to enroll TPM2 with PCR `7`,
- keeps existing passphrase keyslots as fallback,
- updates the matching `/etc/crypttab` entry,
- stages the matching `rd.luks.options=<uuid>=tpm2-device=auto` kernel argument
  via `rpm-ostree kargs` when available.

If root and swap are separate LUKS2 devices, select and manage them separately.

The PCR `7` binding ties unlock to the Secure Boot policy state. If Secure Boot
state or firmware Secure Boot keys change, the normal LUKS passphrase can still
be used.

## What disabling does

When disabling TPM2 unlock, the tool:

- removes TPM2 LUKS slots from the selected device with
  `systemd-cryptenroll --wipe-slot=tpm2`,
- removes `tpm2-device=auto` from the matching `/etc/crypttab` entry,
- removes the matching `rd.luks.options=<uuid>=tpm2-device=auto` boot hint via
  `rpm-ostree kargs` when present.

The normal passphrase keyslot is not removed.

## Recovery

Keep the LUKS passphrase available. TPM2 unlock is a convenience path, not the
only recovery path.

If TPM2 unlock stops working after firmware or Secure Boot changes, unlock with
the LUKS passphrase and run **Manage LUKS TPM** again to refresh the TPM2
enrollment.
