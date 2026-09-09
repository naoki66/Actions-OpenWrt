#!/usr/bin/env bash

openbox_install_var() {
  local install_sh="$1"
  local key="$2"

  awk -v key="$key" '
    $0 ~ "^[[:space:]]*(export[[:space:]]+)?" key "[[:space:]]*=" {
      line = $0
      sub(/^[[:space:]]*(export[[:space:]]+)?[A-Za-z_][A-Za-z0-9_]*[[:space:]]*=[[:space:]]*/, "", line)
      sub(/[[:space:]]*#.*$/, "", line)
      if (line ~ /^"/) {
        sub(/^"/, "", line)
        sub(/".*$/, "", line)
      } else if (line ~ /^\047/) {
        sub(/^\047/, "", line)
        sub(/\047.*$/, "", line)
      }
      print line
      exit
    }
  ' "$install_sh"
}

openbox_expand_template() {
  local value="$1"
  local repo="$2"
  local arch="$3"
  local asset="$4"

  value="${value//\$\{REPO\}/$repo}"
  value="${value//\$REPO/$repo}"
  value="${value//\$\{ARCH\}/$arch}"
  value="${value//\$ARCH/$arch}"
  value="${value//\$\{ASSET\}/$asset}"
  value="${value//\$ASSET/$asset}"
  printf '%s\n' "$value"
}

openbox_download_file() {
  local url="$1"
  local output="$2"

  if command -v curl >/dev/null 2>&1; then
    curl -fsSL -o "$output" "$url"
  elif command -v wget >/dev/null 2>&1; then
    wget -q -O "$output" "$url"
  else
    echo "错误: 缺少 curl/wget，无法下载 Open-Box release"
    return 1
  fi
}

openbox_retry() {
  local attempt=1
  local max_attempts="${OPENBOX_RETRY:-3}"

  while :; do
    "$@" && return 0
    if [ "$attempt" -ge "$max_attempts" ]; then
      return 1
    fi
    echo "命令失败，5 秒后重试($attempt/$max_attempts): $*"
    attempt=$((attempt + 1))
    sleep 5
  done
}

openbox_clone_repo() {
  local url="$1"
  local dst="$2"

  rm -rf "$dst"
  git clone --depth 1 --quiet "$url" "$dst"
}

openbox_build_download_url() {
  local url="$1"
  local mirror="${OPENBOX_RELEASE_MIRROR:-}"

  if [ -n "$mirror" ]; then
    case "$mirror" in
      http://*|https://*) printf '%s/%s\n' "${mirror%/}" "$url" ;;
      *) printf 'https://%s/%s\n' "${mirror%/}" "$url" ;;
    esac
  else
    printf '%s\n' "$url"
  fi
}

openbox_vendor_release() {
  local src_dir="$1"
  local dst_dir="$2"
  local install_sh="$src_dir/scripts/install.sh"
  local repo install_root arch asset_template asset asset_url_template asset_url
  local sha_url_template sha_url asset_download_url sha_download_url tmp round sha_name

  [ -f "$install_sh" ] || {
    echo "错误: 未找到 Open-Box 官方 install.sh: $install_sh"
    return 1
  }

  repo="$(openbox_install_var "$install_sh" REPO)"
  install_root="$(openbox_install_var "$install_sh" INSTALL_ROOT)"
  arch="${OPENBOX_ARCH:-x64}"
  asset_template="$(openbox_install_var "$install_sh" ASSET)"
  asset="$(openbox_expand_template "$asset_template" "$repo" "$arch" "")"
  asset_url_template="$(openbox_install_var "$install_sh" ASSET_URL)"
  sha_url_template="$(openbox_install_var "$install_sh" SHA_URL)"

  [ -n "$repo" ] || {
    echo "错误: 无法从 install.sh 解析 REPO"
    return 1
  }
  [ "$install_root" = "/opt/open-box" ] || {
    echo "错误: install.sh INSTALL_ROOT 非预期: ${install_root:-<empty>}"
    return 1
  }
  [ -n "$asset" ] || {
    echo "错误: 无法从 install.sh 解析 ASSET"
    return 1
  }

  if [ -n "$asset_url_template" ]; then
    asset_url="$(openbox_expand_template "$asset_url_template" "$repo" "$arch" "$asset")"
  else
    asset_url="https://github.com/$repo/releases/latest/download/$asset"
  fi

  if [ -n "$sha_url_template" ]; then
    sha_url_template="${sha_url_template//\$\{ASSET_URL\}/$asset_url}"
    sha_url_template="${sha_url_template//\$ASSET_URL/$asset_url}"
    sha_url="$(openbox_expand_template "$sha_url_template" "$repo" "$arch" "$asset")"
  else
    sha_url="$asset_url.sha256"
  fi

  asset_download_url="$(openbox_build_download_url "$asset_url")"
  sha_download_url="$(openbox_build_download_url "$sha_url")"

  tmp="$(mktemp -d)"
  (
    trap 'rm -rf "$tmp"' EXIT

    round=0
    while :; do
      round=$((round + 1))
      echo "下载 Open-Box 校验文件: $sha_download_url"
      openbox_retry openbox_download_file "$sha_download_url" "$tmp/$asset.sha256.pre"
      echo "下载 Open-Box release: $asset"
      openbox_retry openbox_download_file "$asset_download_url" "$tmp/$asset"
      openbox_retry openbox_download_file "$sha_download_url" "$tmp/$asset.sha256"
      cmp -s "$tmp/$asset.sha256.pre" "$tmp/$asset.sha256" && break
      [ "$round" -ge 3 ] && {
        echo "错误: Open-Box latest release 在下载过程中变化，连续三次校验文件不一致"
        exit 1
      }
      echo "Open-Box release 发生更新，重新下载最新资产..."
    done

    sha_name="$(awk 'NR==1{print $2}' "$tmp/$asset.sha256")"
    sha_name="${sha_name#\*}"
    [ "$sha_name" = "$asset" ] || {
      echo "错误: SHA256 文件资产名不匹配: ${sha_name:-<empty>} != $asset"
      exit 1
    }

    (cd "$tmp" && sha256sum -c "$asset.sha256")

    rm -rf "$dst_dir/opt/open-box"
    mkdir -p "$dst_dir/opt/open-box"
    tar -xzf "$tmp/$asset" -C "$dst_dir/opt/open-box"
  )

  [ -f "$dst_dir/opt/open-box/meta.json" ] || {
    echo "错误: Open-Box release 解包后缺少 meta.json"
    return 1
  }
  [ -f "$dst_dir/opt/open-box/openwrt/initd/openbox-panel" ] || {
    echo "错误: Open-Box release 解包后缺少 openbox-panel init 脚本"
    return 1
  }
  [ -f "$dst_dir/opt/open-box/openwrt/luci/htdocs/luci-static/resources/view/openbox/status.js" ] || {
    echo "错误: Open-Box release 解包后缺少 LuCI status.js"
    return 1
  }
  [ -f "$dst_dir/opt/open-box/openwrt/luci/root/usr/share/luci/menu.d/luci-app-openbox.json" ] || {
    echo "错误: Open-Box release 解包后缺少 LuCI menu 文件"
    return 1
  }
  [ -f "$dst_dir/opt/open-box/openwrt/luci/root/usr/share/rpcd/acl.d/luci-app-openbox.json" ] || {
    echo "错误: Open-Box release 解包后缺少 rpcd ACL 文件"
    return 1
  }

  mkdir -p "$dst_dir/opt/open-box/data"
  printf 'direct\n' > "$dst_dir/opt/open-box/data/channel"
  chmod +x \
    "$dst_dir/opt/open-box/uninstall.sh" \
    "$dst_dir/opt/open-box/update.sh" \
    "$dst_dir/opt/open-box/openwrt/initd/openbox" \
    "$dst_dir/opt/open-box/openwrt/initd/openbox-panel"
  sed -n 's/.*"version" *: *"\([^"]*\)".*/内置 Open-Box 版本: \1/p' "$dst_dir/opt/open-box/meta.json" | head -n 1
}

add_openbox_package() {
  echo "添加 Open-Box 完整内置包..."
  rm -rf package/open-box-src package/luci-app-openbox
  openbox_retry openbox_clone_repo https://github.com/liandu2024/Open-Box.git package/open-box-src || {
    echo "错误: 克隆 Open-Box 失败"
    exit 1
  }

  mkdir -p \
    package/luci-app-openbox/files/etc/uci-defaults \
    package/luci-app-openbox/files/usr/bin \
    package/luci-app-openbox/files/usr/libexec/openbox

  openbox_vendor_release "package/open-box-src" "package/luci-app-openbox/files" || exit 1

  cat > package/luci-app-openbox/Makefile <<'EOF'
include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-openbox
PKG_VERSION:=git
PKG_RELEASE:=1
PKGARCH:=x86_64

include $(INCLUDE_DIR)/package.mk

define Package/luci-app-openbox
  SECTION:=luci
  CATEGORY:=LuCI
  SUBMENU:=3. Applications
  TITLE:=Open-Box bundled panel and LuCI fallback page
  DEPENDS:=@TARGET_x86_64 +luci-base +rpcd +rpcd-mod-file +curl +uclient-fetch +ca-bundle +coreutils-sha256sum
endef

define Package/luci-app-openbox/description
  Bundled Open-Box release payload, LuCI fallback page, service scripts,
  and first-boot panel autostart.
endef

define Build/Prepare
	$(INSTALL_DIR) $(PKG_BUILD_DIR)
endef

define Build/Compile
endef

define Package/luci-app-openbox/install
	$(INSTALL_DIR) $(1)/opt
	$(CP) $(CURDIR)/files/opt/open-box $(1)/opt/
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) $(CURDIR)/files/opt/open-box/openwrt/initd/openbox $(1)/etc/init.d/openbox
	$(INSTALL_BIN) $(CURDIR)/files/opt/open-box/openwrt/initd/openbox-panel $(1)/etc/init.d/openbox-panel
	$(INSTALL_DIR) $(1)/www/luci-static/resources/view/openbox
	$(INSTALL_DATA) $(CURDIR)/files/opt/open-box/openwrt/luci/htdocs/luci-static/resources/view/openbox/status.js $(1)/www/luci-static/resources/view/openbox/status.js
	$(INSTALL_DIR) $(1)/usr/share/luci/menu.d
	$(INSTALL_DATA) $(CURDIR)/files/opt/open-box/openwrt/luci/root/usr/share/luci/menu.d/luci-app-openbox.json $(1)/usr/share/luci/menu.d/luci-app-openbox.json
	$(INSTALL_DIR) $(1)/usr/share/rpcd/acl.d
	$(INSTALL_DATA) $(CURDIR)/files/opt/open-box/openwrt/luci/root/usr/share/rpcd/acl.d/luci-app-openbox.json $(1)/usr/share/rpcd/acl.d/luci-app-openbox.json
	$(INSTALL_DIR) $(1)/usr/libexec/openbox
	$(INSTALL_BIN) $(TOPDIR)/package/open-box-src/scripts/install.sh $(1)/usr/libexec/openbox/install.sh
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(CURDIR)/files/usr/bin/openbox-install $(1)/usr/bin/openbox-install
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_BIN) $(CURDIR)/files/etc/uci-defaults/99-openbox-firstboot $(1)/etc/uci-defaults/99-openbox-firstboot
endef

$(eval $(call BuildPackage,luci-app-openbox))
EOF

  cat > package/luci-app-openbox/files/usr/bin/openbox-install <<'EOF'
#!/bin/sh

INSTALL_ROOT="/opt/open-box"

if [ -r "$INSTALL_ROOT/meta.json" ]; then
  version="$(sed -n 's/.*"version" *: *"\([^"]*\)".*/\1/p' "$INSTALL_ROOT/meta.json" 2>/dev/null | head -n 1)"
  lan_ip="$(uci -q get network.lan.ipaddr 2>/dev/null | tr ' ' '\n' | head -n 1 | cut -d/ -f1)"
  [ -n "$lan_ip" ] || lan_ip="<router-ip>"
  echo "Open-Box already bundled${version:+: $version}"
  echo "Panel: http://$lan_ip:2026"
  exit 0
fi

exec /bin/sh /usr/libexec/openbox/install.sh "$@"
EOF
  chmod +x package/luci-app-openbox/files/usr/bin/openbox-install

  cat > package/luci-app-openbox/files/etc/uci-defaults/99-openbox-firstboot <<'EOF'
#!/bin/sh

if [ -x /etc/init.d/openbox-panel ]; then
  /etc/init.d/openbox-panel enable >/dev/null 2>&1 || true
fi

rm -rf /tmp/luci-*cache* 2>/dev/null || true

if [ -x /etc/init.d/rpcd ]; then
  /etc/init.d/rpcd restart >/dev/null 2>&1 || true
fi

if [ -x /etc/init.d/openbox-panel ]; then
  /etc/init.d/openbox-panel start >/dev/null 2>&1 || true
fi

exit 0
EOF
  chmod +x package/luci-app-openbox/files/etc/uci-defaults/99-openbox-firstboot
}
