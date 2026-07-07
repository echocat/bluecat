# Anaconda installer branding (product.img)

These files are assembled by `mise build:iso` into an Anaconda **`product.img`**
that is placed at `/images/product.img` on the netinstall ISO. Anaconda overlays
a `product.img` on top of its runtime at boot, so this is the supported way to
rebrand the *installer* without rebuilding the Fedora stage2 image.

Contents / effect:

- `buildstamp.in` -> rendered to `/.buildstamp` in the product.img. `Product=`
  and `Version=` here drive the installer title (the "FEDORA 44 INSTALLATION"
  banner becomes "BLUECAT 44 INSTALLATION"). `@@VERSION@@` / `@@UUID@@` are
  substituted at build time.
- `anaconda-gtk.css` -> `/usr/share/anaconda/anaconda-gtk.css`: the bluecat
  brand color and sidebar/topbar logo overrides.
- `sidebar-logo.png` is generated at build time from
  `assets/branding/bluecat-logo-white.svg` and lands at
  `/usr/share/anaconda/pixmaps/sidebar-logo.png`.

The Fedora ISO's `.buildstamp`, GRUB menu titles, volume id and the root
LICENSE/README are handled separately in `mise build:iso` via mkksiso's
`-V` / `-R` / `-a` options.
