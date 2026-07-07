# certs/ — Secure Boot signing material

This directory holds the MOK (Machine Owner Key) certificate used to sign the
kernel modules (NVIDIA, xone).

## Files

| File       | Content             | Commit to repo? |
|------------|---------------------|-----------------|
| `mok.key`  | **PRIVATE** key     | **NEVER** — blocked by `.gitignore` |
| `mok.crt`  | Public cert (PEM)   | Optional (public part only) |
| `mok.der`  | Public cert (DER)   | Optional (gets placed into the image) |

## Generate

```bash
mise keys
```

## Security

- The **private** key (`mok.key`) must never leave the local system / CI
  secret. `.gitignore` blocks `*.key` hard — still, check `git status` before
  every commit.
- If the key is compromised or regenerated, the new **public** cert must be
  enrolled into the firmware again (see the main README, Secure Boot section).
