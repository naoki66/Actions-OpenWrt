# add-luci-app

Place offline OpenWrt or LuCI packages here. The ImmortalWrt build scripts
copy them into the upstream source tree under `package/` before feeds are
installed and before `make defconfig` runs.

Supported forms:

- `luci-app-name/Makefile` plus package files.
- `luci-app-name.tar.gz`, `.tgz`, `.tar.xz`, `.tar.bz2`, or `.zip` containing
  a top-level package directory with a `Makefile`.

Current package:

- `luci-app-openbox.tar.gz`: offline `luci-app-openbox` package generated
  from the upstream Open-Box release payload.
- `luci-app-openbox.version`: the Open-Box tag used by the current archive.
- `luci-app-openbox.tar.gz.sha256`: checksum for the current archive.

Update Open-Box:

```bash
bash scripts/immortalwrt/update-openbox-offline-package.sh latest
```

The default update command vendors only `x64`, which keeps the archive under
GitHub's normal 100 MB single-file limit. If you need another architecture,
run with `OPENBOX_ARCHES=arm64` and store that archive separately.

Pin a specific release:

```bash
bash scripts/immortalwrt/update-openbox-offline-package.sh v0.1.156
```
