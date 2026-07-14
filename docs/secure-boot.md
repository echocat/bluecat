# Secure Boot and MOK enrollment

`bluecat` builds out-of-tree kernel modules, including NVIDIA and xone modules,
and signs them with a local Machine Owner Key (MOK). On systems with UEFI Secure
Boot enabled, the public MOK certificate must be enrolled into the firmware once
before those modules can load.

The public certificate is installed at:

```text
/etc/pki/echocat/mok.der
```

## Automatic prompt

`bluecat` enables `enroll-echocat-mok.service`. The service runs early in boot
when all of these conditions are true:

- UEFI Secure Boot is enabled.
- `/etc/pki/echocat/mok.der` exists.
- the bluecat MOK certificate is not already enrolled.
- `/etc/pki/echocat/mok.der.ignore` does not exist.

The prompt uses a `whiptail` dialog on `/dev/tty9` before the display manager
starts. It offers three choices:

1. Register the key now and reboot into MokManager.
2. Skip for this boot.
3. Skip forever on this installation by creating
   `/etc/pki/echocat/mok.der.ignore`.

When registering, the prompt asks for a one-time MokManager password and passes a
generated password hash to `mokutil`. `mokutil` does not prompt for the password
again during this step.

## Complete enrollment in MokManager

After the key was queued and the machine reboots, the blue MokManager screen
appears before the operating system starts:

1. Select *Enroll MOK*.
2. Select *Continue*.
3. Select *Yes*.
4. Enter the one-time password from the bluecat prompt.
5. Reboot.

Use characters you can enter on a US keyboard layout for the one-time password;
MokManager may not use your normal desktop keyboard layout.

## Why this matters

Without enrollment, Secure Boot can reject bluecat's signed out-of-tree modules.
This affects NVIDIA and xone. On NVIDIA-only systems, a skipped enrollment can
prevent the graphical login from appearing because `nouveau` and `nova_core` are
blacklisted for the proprietary NVIDIA driver stack.

## Manual fallback

If the automatic prompt was skipped or failed, queue the public certificate
manually on the installed system:

```bash
sudo mokutil --import /etc/pki/echocat/mok.der
```

`mokutil` asks for a one-time password. Remember it; it is requested in
MokManager on the next reboot.

Reboot and complete the MokManager flow described above.

## Verify enrollment and module signatures

Check whether the certificate is enrolled:

```bash
mokutil --list-enrolled | grep -i "bluecat"
```

After boot, inspect module signatures:

```bash
modinfo nvidia | grep -i sig
modinfo xone-gip | grep -i sig
```

If the signing key is regenerated in a future image lineage, repeat enrollment
with the new public certificate.
