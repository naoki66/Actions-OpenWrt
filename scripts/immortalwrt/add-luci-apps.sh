#!/usr/bin/env bash

set -euo pipefail

add_luci_apps_repo_root() {
  local script_dir candidate

  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  candidate="$(cd "$script_dir/../.." && pwd)"

  if [ -d "$candidate/add-luci-app" ]; then
    printf '%s\n' "$candidate"
    return 0
  fi

  if [ -n "${GITHUB_WORKSPACE:-}" ] && [ -d "$GITHUB_WORKSPACE/add-luci-app" ]; then
    printf '%s\n' "$GITHUB_WORKSPACE"
    return 0
  fi

  return 1
}

add_luci_apps_package_name() {
  local src="$1"
  local name

  name="$(basename "$src")"
  name="${name%.tar.gz}"
  name="${name%.tgz}"
  name="${name%.tar.xz}"
  name="${name%.txz}"
  name="${name%.tar.bz2}"
  name="${name%.tbz2}"
  name="${name%.zip}"
  printf '%s\n' "$name"
}

add_luci_apps_copy_package_dir() {
  local src_dir="$1"
  local dst_dir="$2"
  local pkg_name

  [ -f "$src_dir/Makefile" ] || {
    echo "错误: 自定义 LuCI 包缺少 Makefile: $src_dir" >&2
    return 1
  }

  pkg_name="$(basename "$src_dir")"
  echo "导入自定义 LuCI 包: $pkg_name"
  rm -rf "$dst_dir/$pkg_name"
  mkdir -p "$dst_dir"
  rsync -a --delete --exclude='.git' "$src_dir"/ "$dst_dir/$pkg_name"/
}

add_luci_apps_import_archive() {
  local archive="$1"
  local dst_dir="$2"
  local tmp top_count top_dir pkg_dir pkg_name
  local found=0

  pkg_name="$(add_luci_apps_package_name "$archive")"
  tmp="$(mktemp -d)"

  case "$archive" in
    *.tar.gz|*.tgz) tar -xzf "$archive" -C "$tmp" ;;
    *.tar.xz|*.txz) tar -xJf "$archive" -C "$tmp" ;;
    *.tar.bz2|*.tbz2) tar -xjf "$archive" -C "$tmp" ;;
    *.zip) unzip -q "$archive" -d "$tmp" ;;
    *)
      echo "跳过不支持的自定义 LuCI 包归档: $archive"
      rm -rf "$tmp"
      return 0
      ;;
  esac

  top_count="$(find "$tmp" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')"
  if [ "$top_count" = "1" ]; then
    top_dir="$(find "$tmp" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
    if [ -f "$top_dir/Makefile" ]; then
      add_luci_apps_copy_package_dir "$top_dir" "$dst_dir"
      rm -rf "$tmp"
      return 0
    fi
  fi

  pkg_dir="$tmp/$pkg_name"
  if [ -f "$pkg_dir/Makefile" ]; then
    add_luci_apps_copy_package_dir "$pkg_dir" "$dst_dir"
    rm -rf "$tmp"
    return 0
  fi

  while IFS= read -r pkg_dir; do
    add_luci_apps_copy_package_dir "$pkg_dir" "$dst_dir"
    found=1
  done < <(find "$tmp" -mindepth 1 -maxdepth 2 -type f -name Makefile -printf '%h\n' | sort -u)

  if [ "$found" != "1" ]; then
    echo "错误: 归档中没有找到带 Makefile 的 OpenWrt 包: $archive" >&2
    rm -rf "$tmp"
    return 1
  fi

  rm -rf "$tmp"
}

import_add_luci_apps() {
  local repo_root src_dir dst_dir item imported=0

  repo_root="${ADD_LUCI_APP_REPO_ROOT:-$(add_luci_apps_repo_root)}" || {
    echo "没有找到配置仓库 add-luci-app 目录，跳过自定义 LuCI 包导入"
    return 0
  }

  src_dir="${ADD_LUCI_APP_DIR:-$repo_root/add-luci-app}"
  dst_dir="${ADD_LUCI_APP_PACKAGE_DIR:-$PWD/package}"

  [ -d "$src_dir" ] || {
    echo "没有找到自定义 LuCI 包目录，跳过: $src_dir"
    return 0
  }

  mkdir -p "$dst_dir"
  shopt -s nullglob

  for item in "$src_dir"/*; do
    case "$item" in
      *.tar.gz|*.tgz|*.tar.xz|*.txz|*.tar.bz2|*.tbz2|*.zip)
        add_luci_apps_import_archive "$item" "$dst_dir"
        imported=$((imported + 1))
        ;;
      *)
        if [ -d "$item" ]; then
          if [ -f "$item/Makefile" ]; then
            add_luci_apps_copy_package_dir "$item" "$dst_dir"
            imported=$((imported + 1))
          else
            while IFS= read -r pkg_dir; do
              add_luci_apps_copy_package_dir "$pkg_dir" "$dst_dir"
              imported=$((imported + 1))
            done < <(find "$item" -mindepth 1 -maxdepth 2 -type f -name Makefile -printf '%h\n' | sort -u)
          fi
        fi
        ;;
    esac
  done

  shopt -u nullglob

  if [ "$imported" -eq 0 ]; then
    echo "add-luci-app 目录为空或没有可导入的包: $src_dir"
  else
    echo "自定义 LuCI 包导入完成: $imported 个"
  fi
}
