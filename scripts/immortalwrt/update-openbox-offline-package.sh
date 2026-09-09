#!/usr/bin/env bash

set -euo pipefail

OPENBOX_REPO="${OPENBOX_REPO:-liandu2024/Open-Box}"
OPENBOX_ARCHES="${OPENBOX_ARCHES:-x64}"
MAX_GITHUB_BLOB_BYTES="${MAX_GITHUB_BLOB_BYTES:-104857600}"
OPENBOX_UPDATE_TMP=""

cleanup() {
  [ -z "${OPENBOX_UPDATE_TMP:-}" ] || rm -rf "$OPENBOX_UPDATE_TMP"
}

trap cleanup EXIT

usage() {
  cat <<'EOF'
Usage:
  bash scripts/immortalwrt/update-openbox-offline-package.sh [latest|vX.Y.Z|X.Y.Z]

Environment:
  OPENBOX_ARCHES="x64"         Architectures to vendor. Use "x64 arm64" only if
                               the resulting archive is stored outside normal Git.
  OPENBOX_REPO=owner/repo      Upstream repo. Default: liandu2024/Open-Box

Examples:
  bash scripts/immortalwrt/update-openbox-offline-package.sh latest
  bash scripts/immortalwrt/update-openbox-offline-package.sh v0.1.156
EOF
}

repo_root() {
  local script_dir candidate

  if git rev-parse --show-toplevel >/dev/null 2>&1; then
    git rev-parse --show-toplevel
    return 0
  fi

  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  candidate="$(cd "$script_dir/../.." && pwd)"
  [ -d "$candidate/add-luci-app" ] && printf '%s\n' "$candidate"
}

download_file() {
  local url="$1"
  local out="$2"

  echo "下载: $url"
  curl -fL --retry 3 --retry-delay 3 --connect-timeout 20 -o "$out" "$url"
}

resolve_latest_tag() {
  local final_url

  final_url="$(
    curl -fsSLI -o /dev/null -w '%{url_effective}' \
      "https://github.com/$OPENBOX_REPO/releases/latest"
  )"

  case "$final_url" in
    */tag/v*) basename "$final_url" ;;
    *)
      echo "错误: 无法解析最新 Open-Box tag: $final_url" >&2
      return 1
      ;;
  esac
}

normalize_tag() {
  local tag="$1"

  case "$tag" in
    latest|"") resolve_latest_tag ;;
    v*) printf '%s\n' "$tag" ;;
    *) printf 'v%s\n' "$tag" ;;
  esac
}

write_package_makefile() {
  local package_dir="$1"
  local version="$2"

  cat > "$package_dir/Makefile" <<EOF
include \$(TOPDIR)/rules.mk

PKG_NAME:=luci-app-openbox
PKG_VERSION:=$version
PKG_RELEASE:=1

PKG_LICENSE:=MIT
PKG_MAINTAINER:=liandu2024
PKGARCH:=all

OPENBOX_RELEASE_ARCH:=\$(if \$(filter x86_64,\$(ARCH)),x64,\$(if \$(filter aarch64,\$(ARCH)),arm64))
OPENBOX_LIBC_SONAME:=\$(if \$(filter x86_64,\$(ARCH)),libc.musl-x86_64.so.1,\$(if \$(filter aarch64,\$(ARCH)),libc.musl-aarch64.so.1))

include \$(INCLUDE_DIR)/package.mk

define Package/\$(PKG_NAME)
  SECTION:=luci
  CATEGORY:=LuCI
  SUBMENU:=3. Applications
  TITLE:=Open-Box offline runtime and LuCI fallback page
  URL:=https://github.com/$OPENBOX_REPO
  MENU:=1
  DEPENDS:=+libc +luci-base +rpcd-mod-file
endef

define Package/\$(PKG_NAME)/description
  Offline Open-Box runtime package extracted from the upstream release
  payload. This installs the /opt/open-box runtime together with the same
  LuCI, rpcd ACL, init.d, update, and uninstall files that the upstream
  online install script copies onto the router.
endef

define Build/Compile
endef

define Package/\$(PKG_NAME)/install
	[ -n "\$(OPENBOX_RELEASE_ARCH)" ] || { echo "Unsupported Open-Box release architecture for ARCH=\$(ARCH)" >&2; exit 1; }
	[ -d "./full-root/\$(OPENBOX_RELEASE_ARCH)" ] || { echo "Missing ./full-root/\$(OPENBOX_RELEASE_ARCH); run update-openbox-offline-package.sh for this arch first" >&2; exit 1; }

	\$(INSTALL_DIR) \$(1)/opt/open-box
	\$(CP) ./full-root/\$(OPENBOX_RELEASE_ARCH)/. \$(1)/opt/open-box/
	\$(if \$(OPENBOX_LIBC_SONAME),\$(LN) ../../../../lib/libc.so \$(1)/opt/open-box/node/lib/\$(OPENBOX_LIBC_SONAME))

	\$(INSTALL_DIR) \$(1)/etc/init.d
	\$(INSTALL_BIN) ./full-root/\$(OPENBOX_RELEASE_ARCH)/openwrt/initd/openbox \$(1)/etc/init.d/openbox
	\$(INSTALL_BIN) ./full-root/\$(OPENBOX_RELEASE_ARCH)/openwrt/initd/openbox-panel \$(1)/etc/init.d/openbox-panel

	\$(INSTALL_DIR) \$(1)/www/luci-static/resources/view/openbox
	\$(INSTALL_DATA) ./full-root/\$(OPENBOX_RELEASE_ARCH)/openwrt/luci/htdocs/luci-static/resources/view/openbox/status.js \\
		\$(1)/www/luci-static/resources/view/openbox/status.js

	\$(INSTALL_DIR) \$(1)/usr/share/luci/menu.d
	\$(INSTALL_DATA) ./full-root/\$(OPENBOX_RELEASE_ARCH)/openwrt/luci/root/usr/share/luci/menu.d/luci-app-openbox.json \\
		\$(1)/usr/share/luci/menu.d/luci-app-openbox.json

	\$(INSTALL_DIR) \$(1)/usr/share/rpcd/acl.d
	\$(INSTALL_DATA) ./full-root/\$(OPENBOX_RELEASE_ARCH)/openwrt/luci/root/usr/share/rpcd/acl.d/luci-app-openbox.json \\
		\$(1)/usr/share/rpcd/acl.d/luci-app-openbox.json

	\$(INSTALL_DIR) \$(1)/opt/open-box
	\$(INSTALL_BIN) ./full-root/\$(OPENBOX_RELEASE_ARCH)/update.sh \$(1)/opt/open-box/update.sh
	\$(INSTALL_BIN) ./full-root/\$(OPENBOX_RELEASE_ARCH)/uninstall.sh \$(1)/opt/open-box/uninstall.sh

	\$(INSTALL_DIR) \$(1)/etc/rc.d
	\$(LN) ../init.d/openbox-panel \$(1)/etc/rc.d/S98openbox-panel
endef

define Package/\$(PKG_NAME)/postinst
#!/bin/sh
[ -n "\$\${IPKG_INSTROOT}" ] && exit 0
rm -rf /tmp/luci-*cache* 2>/dev/null || true
[ -x /etc/init.d/rpcd ] && /etc/init.d/rpcd restart >/dev/null 2>&1 || true
[ -x /etc/init.d/openbox-panel ] && /etc/init.d/openbox-panel enable >/dev/null 2>&1 || true
[ -x /etc/init.d/openbox-panel ] && /etc/init.d/openbox-panel start >/dev/null 2>&1 || true
exit 0
endef

define Package/\$(PKG_NAME)/prerm
#!/bin/sh
[ -n "\$\${IPKG_INSTROOT}" ] && exit 0
[ -x /etc/init.d/openbox-panel ] && /etc/init.d/openbox-panel stop >/dev/null 2>&1 || true
[ -x /etc/init.d/openbox ] && /etc/init.d/openbox stop >/dev/null 2>&1 || true
exit 0
endef

\$(eval \$(call BuildPackage,\$(PKG_NAME)))
EOF
}

validate_payload() {
  local root="$1"
  local arch="$2"

  [ -f "$root/meta.json" ] || { echo "错误: $arch 缺少 meta.json" >&2; return 1; }
  [ -x "$root/node/bin/node" ] || { echo "错误: $arch 缺少 node/bin/node" >&2; return 1; }
  [ -x "$root/bin/sing-box" ] || { echo "错误: $arch 缺少 bin/sing-box" >&2; return 1; }
  [ -f "$root/panel/server/index.mjs" ] || { echo "错误: $arch 缺少 panel/server/index.mjs" >&2; return 1; }
  [ -f "$root/openwrt/luci/root/usr/share/luci/menu.d/luci-app-openbox.json" ] || { echo "错误: $arch 缺少 LuCI menu" >&2; return 1; }
  [ -f "$root/openwrt/luci/root/usr/share/rpcd/acl.d/luci-app-openbox.json" ] || { echo "错误: $arch 缺少 rpcd ACL" >&2; return 1; }
  [ -f "$root/openwrt/luci/htdocs/luci-static/resources/view/openbox/status.js" ] || { echo "错误: $arch 缺少 LuCI status.js" >&2; return 1; }
  [ -x "$root/openwrt/initd/openbox-panel" ] || { echo "错误: $arch 缺少 openbox-panel init 脚本" >&2; return 1; }
}

main() {
  local requested_tag="${1:-latest}"
  local root tag version out_dir tmp package_dir archive_tmp archive_final size arch asset url sha_url

  case "$requested_tag" in
    -h|--help)
      usage
      exit 0
      ;;
  esac

  root="$(repo_root)"
  [ -n "$root" ] || { echo "错误: 无法定位配置仓库根目录" >&2; exit 1; }

  tag="$(normalize_tag "$requested_tag")"
  version="${tag#v}"
  out_dir="$root/add-luci-app"
  OPENBOX_UPDATE_TMP="$(mktemp -d)"
  tmp="$OPENBOX_UPDATE_TMP"
  package_dir="$tmp/luci-app-openbox"
  archive_tmp="$tmp/luci-app-openbox.tar.gz"
  archive_final="$out_dir/luci-app-openbox.tar.gz"

  mkdir -p "$package_dir/full-root" "$out_dir"

  for arch in $OPENBOX_ARCHES; do
    asset="open-box-linux-$arch.tar.gz"
    url="https://github.com/$OPENBOX_REPO/releases/download/$tag/$asset"
    sha_url="$url.sha256"

    download_file "$sha_url" "$tmp/$asset.sha256"
    download_file "$url" "$tmp/$asset"

    (cd "$tmp" && sha256sum -c "$asset.sha256")
    mkdir -p "$package_dir/full-root/$arch"
    tar -xzf "$tmp/$asset" -C "$package_dir/full-root/$arch"
    validate_payload "$package_dir/full-root/$arch" "$arch"
  done

  write_package_makefile "$package_dir" "$version"
  cat > "$package_dir/README.md" <<EOF
# luci-app-openbox

Offline Open-Box package generated from $OPENBOX_REPO $tag.

Regenerate from this repository root:

\`\`\`bash
bash scripts/immortalwrt/update-openbox-offline-package.sh latest
\`\`\`
EOF

  tar -czf "$archive_tmp" -C "$tmp" luci-app-openbox
  size="$(wc -c < "$archive_tmp" | tr -d ' ')"

  if [ "$size" -ge "$MAX_GITHUB_BLOB_BYTES" ]; then
    echo "错误: $archive_tmp 大小为 $size bytes，超过 GitHub 单文件 100MB 限制" >&2
    echo "建议只打包一个架构，或改用仓库 Release/外部下载源保存离线包。" >&2
    exit 1
  fi

  mv "$archive_tmp" "$archive_final"
  echo "$tag" > "$out_dir/luci-app-openbox.version"
  (cd "$out_dir" && sha256sum luci-app-openbox.tar.gz) > "$out_dir/luci-app-openbox.tar.gz.sha256"
  echo "已更新: $archive_final"
  echo "Open-Box tag: $tag"
  echo "大小: $size bytes"
}

main "$@"
