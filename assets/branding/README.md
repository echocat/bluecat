# echocat branding assets

This directory holds the **echocat / bluecat** branding: the source artwork and
the master file it is derived from. The image assets under `system_files/` are
**generated** from these sources by the `mise branding` task.

## Source files (edit these)

| File                      | Content                                  | Role                                    |
|---------------------------|------------------------------------------|-----------------------------------------|
| `bluecat-logo.af`         | Affinity Designer master                 | editable master (not used by the build) |
| `bluecat-logo-symbol.svg` | square mark only (`viewBox 0 0 182 182`) | app icon / os-release `LOGO`            |
| `bluecat-logo.svg`        | mark + wordmark (`viewBox 0 0 838 182`)  | full logo (pixmap)                      |
| `bluecat-logo-white.svg`  | white mark + wordmark                    | Plymouth / SDDM (dark backgrounds)      |

Brand accent color: **`#006fb3`** (used for os-release `ANSI_COLOR`).

## Generating the image assets

```bash
mise branding
```

This renders the SVGs (pure Deno via `@resvg/resvg-wasm`, no CLI dependency)
into `system_files/`, which the build copies into the image:

| Generated file (under `system_files/`)                             | Visible surface                          |
|--------------------------------------------------------------------|------------------------------------------|
| `usr/share/pixmaps/bluecat-logo-icon.svg`                          | os-release `LOGO` / KDE About            |
| `usr/share/icons/hicolor/scalable/apps/bluecat-logo-icon.svg`      | scalable app icon                        |
| `usr/share/icons/hicolor/{16..256}x.../apps/bluecat-logo-icon.png` | app icon (raster)                        |
| `usr/share/pixmaps/bluecat-logo.svg` + `.png`                      | full logo pixmap                         |
| `usr/share/bluecat/branding/plymouth-watermark.png`                | Plymouth boot splash (staged; see below) |
| `usr/share/sddm/themes/bluecat/logo.png` + `symbol.png`            | SDDM login assets                        |

The generated files are **committed** to the repository. Re-run `mise branding`
and commit the result whenever a source SVG changes.

## Trademark constraints

- These are echocat's own artwork (echocat holds the rights).
- They contain **no** Fedora trademarks and are not confusingly similar to
  Fedora branding, keeping the image compliant with the Fedora Remix trademark
  guidelines.

## Notes / open points

- **Plymouth**: the watermark is **staged** in `usr/share/bluecat/branding/`
  (not shipped straight into the rpm-managed `spinner` theme dir, which
  `rpm-ostree` would clean out). `image-setup.sh` copies it to
  `/usr/share/plymouth/themes/spinner/watermark.png` **after** the last
  `rpm-ostree` transaction. The default `bgrt` theme reads the watermark from
  the spinner dir. The default theme is not force-switched (testable on real
  hardware); no `plymouth-set-default-theme -R` is run (it would drop the file).
- **Boot splash + LUKS unlock come from the initramfs, not from `/usr`.** The
  running system (shutdown splash, KDE "About") uses the watermark in `/usr`
  and shows bluecat. The **boot** splash and the LUKS password prompt are
  rendered from the initramfs, which bakes in the Plymouth theme at the time it
  is generated. Consequences:
  - **Fresh install** (Anaconda / bootc-installer from the image): the
    ISO Kickstart runs `rpm-ostree initramfs --enable` against the installed
    sysroot -> boot splash shows bluecat.
  - **Rebase onto an existing Fedora system**: the old initramfs (with Fedora's
    watermark) is kept until it is regenerated, so the boot splash may still
    show Fedora. A user can force it with `sudo rpm-ostree initramfs --enable`
    (regenerates the initramfs from the current deployment).
  - We do **not** rebuild the initramfs with plain `dracut` during the container
    build, because that can omit ostree/bootc's prepare-root integration and
    break switch-root.
- **SDDM**: the logo assets are provided under `usr/share/sddm/themes/bluecat/`.
  Wiring a specific SDDM theme/config to display them is left as a documented
  step, as it depends on the chosen SDDM theme.
- **KDE application launcher**: `image-setup.sh` maps the generated
  `bluecat-logo-icon.svg` to Plasma's default `start-here` / `start-here-kde`
  icon names after package transactions have completed, including Breeze theme
  slots when present.
