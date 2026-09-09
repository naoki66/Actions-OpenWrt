#!/usr/bin/env bash

set -euo pipefail

DEFAULT_CONFIG_REPO_URL="https://github.com/naoki66/Actions-OpenWrt.git"
WORK_ROOT="${WORK_ROOT:-$HOME/actions-openwrt-build}"
CONFIG_REPO_URL="${CONFIG_REPO_URL:-}"
CONFIG_REPO_DIR="${CONFIG_REPO_DIR:-}"
TARGET="all"
DOWNLOAD_JOBS="${DOWNLOAD_JOBS:-8}"
COMPILE_JOBS="${COMPILE_JOBS:-2}"
INSTALL_DEPS=1
CLEAN_SOURCE=0
CLONE_CONFIG_REPO=0
ALLOW_ROOT=0
DRY_RUN=0

usage() {
  cat <<'EOF'
Usage:
  bash scripts/debian-build-from-workflow.sh [options]

Options:
  -t, --target TARGET       25.12, master, all, or a workflow yml path. Default: all
  -w, --work-root DIR       Build workspace. Default: $HOME/actions-openwrt-build
      --repo-url URL        Config repo URL used when cloning this repository
      --repo-dir DIR        Existing or cloned config repo directory
      --clone-repo          Force clone/update config repo instead of using current checkout
      --download-jobs N     make download parallelism. Default: 8
      --jobs N              make compile parallelism. Default: 2
      --skip-deps           Skip Debian dependency installation
      --deps-only           Install Debian dependencies and exit
      --dry-run             Validate workflow mapping without cloning source or compiling
      --clean-source        Remove the ImmortalWrt source tree before cloning
      --allow-root          Allow building as root, useful only in disposable containers
  -h, --help                Show this help

Examples:
  bash scripts/debian-build-from-workflow.sh --target 25.12
  bash scripts/debian-build-from-workflow.sh --target master --work-root /mnt/openwrt-build
  bash scripts/debian-build-from-workflow.sh --target all --jobs 2

The script reads workflow env values such as REPO_URL, REPO_BRANCH,
CONFIG_FILE, DIY_P1_SH, and DIY_P2_SH. It skips GitHub Actions-only steps:
checkout action, changelog generation, artifact upload, release creation,
workflow cleanup, and cache save.
EOF
}

log() {
  printf '\033[1;32m[local-build]\033[0m %s\n' "$*"
}

warn() {
  printf '\033[1;33m[local-build] warning:\033[0m %s\n' "$*" >&2
}

die() {
  printf '\033[1;31m[local-build] error:\033[0m %s\n' "$*" >&2
  exit 1
}

summarize_compile_log() {
  local log_file="$1"
  local pattern='(ERROR:|Error [0-9]+|error:|fatal:|failed|No such file|not found|Permission denied|Killed|undefined reference|collect2|ninja: build stopped|make\[[0-9]+\]: \*\*\*)'
  local first_error start end

  [ -f "$log_file" ] || {
    warn "Compile log not found: $log_file"
    return 0
  }

  log "Compile failed; showing likely error lines from $log_file"
  grep -nEi "$pattern" "$log_file" | head -n 120 || true

  first_error="$(grep -nEi "$pattern" "$log_file" | head -n 1 | cut -d: -f1 || true)"
  if [ -n "$first_error" ]; then
    if [ "$first_error" -gt 80 ]; then
      start=$((first_error - 80))
    else
      start=1
    fi
    end=$((first_error + 160))
    log "First error context: lines $start-$end"
    sed -n "${start},${end}p" "$log_file" || true
  fi
}

trim_value() {
  local value="$1"
  value="${value%%#*}"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  if [[ "$value" == \"*\" && "$value" == *\" ]]; then
    value="${value:1:${#value}-2}"
  elif [[ "$value" == \'*\' && "$value" == *\' ]]; then
    value="${value:1:${#value}-2}"
  fi
  printf '%s\n' "$value"
}

workflow_env() {
  local workflow="$1"
  local key="$2"
  local line value

  line="$(
    awk -v key="$key" '
      /^env:[[:space:]]*$/ { in_env = 1; next }
      in_env && /^[^[:space:]#][^:]*:/ { exit }
      in_env {
        sub(/\r$/, "")
        pattern = "^[[:space:]]*" key ":[[:space:]]*"
        if ($0 ~ pattern) {
          print
          exit
        }
      }
    ' "$workflow"
  )"

  [ -n "$line" ] || return 1
  value="${line#*:}"
  trim_value "$value"
}

run() {
  log "$*"
  "$@"
}

sudo_cmd() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    die "sudo is required to install dependencies. Install sudo or rerun with --skip-deps after installing dependencies."
  fi
}

install_deps() {
  command -v apt-get >/dev/null 2>&1 || die "This script expects Debian with apt-get."

  log "Installing Debian build dependencies"
  sudo_cmd apt-get -qq update

  local packages=(
    ack antlr3 asciidoc autoconf automake autopoint binutils bison
    build-essential bzip2 ca-certificates ccache clang cmake cpio curl
    device-tree-compiler ecj fastjar file flex gawk gettext gcc-multilib
    g++-multilib git gnutls-dev gperf haveged help2man intltool jq
    lib32gcc-s1 libc6-dev-i386 libelf-dev libglib2.0-dev libgmp-dev
    libgmp3-dev libgnutls28-dev libltdl-dev libmpc-dev libmpfr-dev
    libncurses-dev libncurses5-dev libncursesw5-dev libpython3-dev
    libreadline-dev libssl-dev libtool libyaml-dev libz-dev lld llvm
    lrzsz make mkisofs msmtp nano ninja-build p7zip p7zip-full patch
    pkg-config pkgconf python3 python3-pip python3-ply python3-docutils
    python3-pyelftools python3-setuptools qemu-utils quilt re2c rsync scons
    squashfs-tools subversion swig texinfo time uglifyjs unzip upx-ucl vim
    wget xmlto xsltproc xxd zlib1g-dev zstd
  )
  local available=()
  local missing=()
  local pkg

  for pkg in "${packages[@]}"; do
    if apt-cache show "$pkg" >/dev/null 2>&1; then
      available+=("$pkg")
    else
      missing+=("$pkg")
    fi
  done

  if [ "${#missing[@]}" -gt 0 ]; then
    warn "These packages were not found in apt metadata and will be skipped: ${missing[*]}"
  fi

  sudo_cmd apt-get -qq install -y --no-install-recommends "${available[@]}"
}

repo_root_from_script() {
  local script_dir candidate
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  candidate="$(cd "$script_dir/.." && pwd)"
  if git -C "$candidate" rev-parse --is-inside-work-tree >/dev/null 2>&1 &&
     [ -d "$candidate/.github/workflows" ]; then
    git -C "$candidate" rev-parse --show-toplevel
  fi
}

resolve_config_repo() {
  local current_root
  mkdir -p "$WORK_ROOT"

  if [ -z "$CONFIG_REPO_URL" ]; then
    current_root="$(repo_root_from_script || true)"
    if [ -n "$current_root" ]; then
      CONFIG_REPO_URL="$(git -C "$current_root" remote get-url origin 2>/dev/null || true)"
    fi
    CONFIG_REPO_URL="${CONFIG_REPO_URL:-$DEFAULT_CONFIG_REPO_URL}"
  fi

  if [ -z "$CONFIG_REPO_DIR" ]; then
    current_root="$(repo_root_from_script || true)"
    if [ -n "$current_root" ] && [ "$CLONE_CONFIG_REPO" -eq 0 ]; then
      CONFIG_REPO_DIR="$current_root"
      log "Using current config repo: $CONFIG_REPO_DIR"
      return
    fi
    CONFIG_REPO_DIR="$WORK_ROOT/Actions-OpenWrt"
  fi

  if [ ! -d "$CONFIG_REPO_DIR/.git" ]; then
    run git clone --depth 1 --recurse-submodules "$CONFIG_REPO_URL" "$CONFIG_REPO_DIR"
  else
    log "Updating config repo: $CONFIG_REPO_DIR"
    git -C "$CONFIG_REPO_DIR" pull --ff-only
    git -C "$CONFIG_REPO_DIR" submodule update --init --recursive
  fi
}

workflow_for_target() {
  local target="$1"
  case "$target" in
    25.12|openwrt-25.12|immortalwrt-25.12)
      printf '%s\n' ".github/workflows/build_ImmortalWrt_25.12.yml"
      ;;
    master|matser|immortalwrt-master)
      printf '%s\n' ".github/workflows/build_ImmortalWrt_matser.yml"
      ;;
    *.yml|*.yaml)
      printf '%s\n' "$target"
      ;;
    *)
      die "Unknown target: $target"
      ;;
  esac
}

safe_target_id() {
  printf '%s\n' "$1" | tr -c 'A-Za-z0-9._-' '_'
}

clone_or_update_source() {
  local repo_url="$1"
  local repo_branch="$2"
  local source_dir="$3"

  if [ "$CLEAN_SOURCE" -eq 1 ] && [ -d "$source_dir" ]; then
    local real_source real_work
    real_source="$(realpath -m "$source_dir")"
    real_work="$(realpath -m "$WORK_ROOT")"
    case "$real_source" in
      "$real_work"/*) rm -rf "$source_dir" ;;
      *) die "Refusing to remove source outside work root: $source_dir" ;;
    esac
  fi

  if [ ! -d "$source_dir/.git" ]; then
    mkdir -p "$(dirname "$source_dir")"
    run git clone -b "$repo_branch" --single-branch --filter=blob:none "$repo_url" "$source_dir"
  else
    log "Updating ImmortalWrt source: $source_dir"
    git -C "$source_dir" remote set-url origin "$repo_url"
    git -C "$source_dir" fetch --depth 1 origin "$repo_branch"
    git -C "$source_dir" checkout -B "$repo_branch" "origin/$repo_branch"
  fi
}

copy_custom_files() {
  local config_repo="$1"
  local source_dir="$2"
  local custom_dir="$config_repo/files/immortalwrt"

  if [ -d "$custom_dir" ]; then
    mkdir -p "$source_dir/files"
    run rsync -a --delete --exclude='.gitkeep' --exclude='.gitignore' "$custom_dir"/ "$source_dir/files"/
  else
    log "No custom files directory found, skipping: $custom_dir"
  fi
}

build_one_workflow() {
  local target="$1"
  local workflow_rel workflow repo_url repo_branch config_file diy_p1 diy_p2
  local target_id source_dir artifact_dir log_dir firmware_dir

  workflow_rel="$(workflow_for_target "$target")"
  workflow="$CONFIG_REPO_DIR/$workflow_rel"
  [ -f "$workflow" ] || die "Workflow not found: $workflow"

  repo_url="$(workflow_env "$workflow" REPO_URL)" || die "REPO_URL missing in $workflow_rel"
  repo_branch="$(workflow_env "$workflow" REPO_BRANCH)" || die "REPO_BRANCH missing in $workflow_rel"
  config_file="$(workflow_env "$workflow" CONFIG_FILE)" || die "CONFIG_FILE missing in $workflow_rel"
  diy_p1="$(workflow_env "$workflow" DIY_P1_SH)" || die "DIY_P1_SH missing in $workflow_rel"
  diy_p2="$(workflow_env "$workflow" DIY_P2_SH)" || die "DIY_P2_SH missing in $workflow_rel"

  [ -f "$CONFIG_REPO_DIR/$config_file" ] || die "Config file missing: $config_file"
  [ -f "$CONFIG_REPO_DIR/$diy_p1" ] || die "DIY_P1_SH missing: $diy_p1"
  [ -f "$CONFIG_REPO_DIR/$diy_p2" ] || die "DIY_P2_SH missing: $diy_p2"

  target_id="$(safe_target_id "$repo_branch")"
  source_dir="$WORK_ROOT/sources/$target_id/immortalwrt"
  artifact_dir="$WORK_ROOT/artifacts/$target_id"
  log_dir="$WORK_ROOT/logs/$target_id"
  mkdir -p "$artifact_dir" "$log_dir"

  log "Workflow: $workflow_rel"
  log "Source: $repo_url ($repo_branch)"
  log "Config: $config_file"
  log "DIY scripts: $diy_p1, $diy_p2"
  log "Skipping GitHub Actions-only steps: checkout action, changelog, upload, release, cleanup, cache"

  if [ "$DRY_RUN" -eq 1 ]; then
    log "Dry run only, build steps skipped"
    return
  fi

  clone_or_update_source "$repo_url" "$repo_branch" "$source_dir"

  (
    cd "$source_dir"
    run bash "$CONFIG_REPO_DIR/$diy_p1"
    run ./scripts/feeds update -a
    rm -rf feeds/packages/net/mosdns feeds/packages/net/v2ray-geodata
    run ./scripts/feeds install -a -f
  )

  copy_custom_files "$CONFIG_REPO_DIR" "$source_dir"
  cp "$CONFIG_REPO_DIR/$config_file" "$source_dir/.config"

  (
    cd "$source_dir"
    run bash "$CONFIG_REPO_DIR/$diy_p2"
    run make defconfig
    run make download -j"$DOWNLOAD_JOBS"
    find dl -size -1024c -type f -print -delete
    log "Compiling with make V=s -j$COMPILE_JOBS"
    if ! make V=s -j"$COMPILE_JOBS" 2>&1 | tee "$log_dir/compile.log" | tail -200; then
      summarize_compile_log "$log_dir/compile.log"
      exit 1
    fi
  )

  firmware_dir="$(find "$source_dir/bin/targets" -mindepth 2 -maxdepth 2 -type d | head -n 1 || true)"
  [ -n "$firmware_dir" ] || die "Firmware output directory not found under $source_dir/bin/targets"

  rm -rf "$artifact_dir"
  mkdir -p "$artifact_dir"
  run rsync -a --exclude='packages' "$firmware_dir"/ "$artifact_dir"/
  log "Firmware copied to: $artifact_dir"
  log "Compile log: $log_dir/compile.log"
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -t|--target)
        TARGET="${2:?missing target}"
        shift 2
        ;;
      -w|--work-root)
        WORK_ROOT="${2:?missing work root}"
        shift 2
        ;;
      --repo-url)
        CONFIG_REPO_URL="${2:?missing repo url}"
        shift 2
        ;;
      --repo-dir)
        CONFIG_REPO_DIR="${2:?missing repo dir}"
        shift 2
        ;;
      --clone-repo)
        CLONE_CONFIG_REPO=1
        shift
        ;;
      --download-jobs)
        DOWNLOAD_JOBS="${2:?missing download jobs}"
        shift 2
        ;;
      --jobs|-j)
        COMPILE_JOBS="${2:?missing jobs}"
        shift 2
        ;;
      --skip-deps)
        INSTALL_DEPS=0
        shift
        ;;
      --deps-only)
        TARGET="deps-only"
        shift
        ;;
      --dry-run)
        DRY_RUN=1
        INSTALL_DEPS=0
        shift
        ;;
      --clean-source)
        CLEAN_SOURCE=1
        shift
        ;;
      --allow-root)
        ALLOW_ROOT=1
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        die "Unknown option: $1"
        ;;
    esac
  done
}

main() {
  parse_args "$@"

  if [ "$(id -u)" -eq 0 ] && [ "$ALLOW_ROOT" -ne 1 ]; then
    die "Do not run the OpenWrt build as root. Use a normal user with sudo, or pass --allow-root only inside a disposable container."
  fi

  if [ "$INSTALL_DEPS" -eq 1 ]; then
    install_deps
  fi

  if [ "$TARGET" = "deps-only" ]; then
    exit 0
  fi

  resolve_config_repo

  case "$TARGET" in
    all)
      build_one_workflow "25.12"
      build_one_workflow "master"
      ;;
    *)
      build_one_workflow "$TARGET"
      ;;
  esac
}

main "$@"
