#!/usr/bin/env bash

add_openbox_package() {
  echo "添加 Open-Box LuCI app 和一键安装器..."
  rm -rf package/open-box-src package/luci-app-openbox
  git clone --depth 1 https://github.com/liandu2024/Open-Box.git package/open-box-src || {
    echo "错误: 克隆 Open-Box 失败"
    exit 1
  }

  mkdir -p \
    package/luci-app-openbox/files/usr/bin \
    package/luci-app-openbox/files/usr/share/luci/menu.d \
    package/luci-app-openbox/files/usr/share/rpcd/acl.d \
    package/luci-app-openbox/files/www/luci-static/resources/view/openbox

  cat > package/luci-app-openbox/Makefile <<'EOF'
include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-openbox
PKG_VERSION:=git
PKG_RELEASE:=1

include $(INCLUDE_DIR)/package.mk

define Package/luci-app-openbox
  SECTION:=luci
  CATEGORY:=LuCI
  SUBMENU:=3. Applications
  TITLE:=Open-Box LuCI fallback page and installer
  DEPENDS:=+luci-base +rpcd +rpcd-mod-file +curl +uclient-fetch +ca-bundle
  PKGARCH:=all
endef

define Package/luci-app-openbox/description
  LuCI fallback page, service scripts, and first-run installer for Open-Box.
endef

define Build/Prepare
	$(INSTALL_DIR) $(PKG_BUILD_DIR)
endef

define Build/Compile
endef

define Package/luci-app-openbox/install
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) $(TOPDIR)/package/open-box-src/openwrt/initd/openbox $(1)/etc/init.d/openbox
	$(INSTALL_BIN) $(TOPDIR)/package/open-box-src/openwrt/initd/openbox-panel $(1)/etc/init.d/openbox-panel
	$(INSTALL_DIR) $(1)/www/luci-static/resources/view/openbox
	$(INSTALL_DATA) $(TOPDIR)/package/open-box-src/openwrt/luci/htdocs/luci-static/resources/view/openbox/status.js $(1)/www/luci-static/resources/view/openbox/status.js
	$(INSTALL_DATA) $(CURDIR)/files/www/luci-static/resources/view/openbox/install.js $(1)/www/luci-static/resources/view/openbox/install.js
	$(INSTALL_DIR) $(1)/usr/share/luci/menu.d
	$(INSTALL_DATA) $(TOPDIR)/package/open-box-src/openwrt/luci/root/usr/share/luci/menu.d/luci-app-openbox.json $(1)/usr/share/luci/menu.d/luci-app-openbox.json
	$(INSTALL_DATA) $(CURDIR)/files/usr/share/luci/menu.d/luci-app-openbox-installer.json $(1)/usr/share/luci/menu.d/luci-app-openbox-installer.json
	$(INSTALL_DIR) $(1)/usr/share/rpcd/acl.d
	$(INSTALL_DATA) $(TOPDIR)/package/open-box-src/openwrt/luci/root/usr/share/rpcd/acl.d/luci-app-openbox.json $(1)/usr/share/rpcd/acl.d/luci-app-openbox.json
	$(INSTALL_DATA) $(CURDIR)/files/usr/share/rpcd/acl.d/luci-app-openbox-installer.json $(1)/usr/share/rpcd/acl.d/luci-app-openbox-installer.json
	$(INSTALL_DIR) $(1)/usr/libexec/openbox
	$(INSTALL_BIN) $(TOPDIR)/package/open-box-src/scripts/install.sh $(1)/usr/libexec/openbox/install.sh
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(CURDIR)/files/usr/bin/openbox-install $(1)/usr/bin/openbox-install
	$(INSTALL_BIN) $(CURDIR)/files/usr/bin/openbox-bootstrap $(1)/usr/bin/openbox-bootstrap
endef

$(eval $(call BuildPackage,luci-app-openbox))
EOF

  cat > package/luci-app-openbox/files/usr/bin/openbox-install <<'EOF'
#!/bin/sh
exec /bin/sh /usr/libexec/openbox/install.sh "$@"
EOF

  cat > package/luci-app-openbox/files/usr/bin/openbox-bootstrap <<'EOF'
#!/bin/sh

set -eu

INSTALL_SCRIPT="/usr/libexec/openbox/install.sh"
INSTALL_ROOT="/opt/open-box"
STATUS_PATH="${TMPDIR:-/tmp}/openbox-install.status"
LOG_PATH="${TMPDIR:-/tmp}/openbox-install.log"
PID_PATH="${TMPDIR:-/tmp}/openbox-install.pid"

read_version() {
  sed -n 's/.*"version" *: *"\([^"]*\)".*/\1/p' "$INSTALL_ROOT/meta.json" 2>/dev/null | head -n 1
}

write_status() {
  stage="$1"
  message="${2:-}"
  pid=""
  [ -r "$PID_PATH" ] && pid="$(cat "$PID_PATH" 2>/dev/null || true)"
  tmp="$STATUS_PATH.$$"
  {
    echo "stage=$stage"
    echo "message=$message"
    echo "pid=$pid"
    echo "updated=$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null || true)"
  } > "$tmp"
  mv -f "$tmp" "$STATUS_PATH"
}

is_running() {
  [ -r "$PID_PATH" ] || return 1
  pid="$(cat "$PID_PATH" 2>/dev/null || true)"
  [ -n "$pid" ] || return 1
  kill -0 "$pid" 2>/dev/null
}

validate_install_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --direct|--mirror) ;;
      http://*|https://*) ;;
      *) echo "unsupported argument: $1" >&2; return 1 ;;
    esac
    shift
  done
}

start_install() {
  validate_install_args "$@"
  [ -x "$INSTALL_SCRIPT" ] || {
    write_status failed "installer not found: $INSTALL_SCRIPT"
    echo "missing_installer"
    exit 1
  }

  if [ -r "$INSTALL_ROOT/meta.json" ]; then
    version="$(read_version)"
    write_status done "already installed${version:+: $version}"
    echo "already_installed"
    exit 0
  fi

  if is_running; then
    write_status running "install already running"
    echo "running"
    exit 0
  fi

  : > "$LOG_PATH"
  (
    trap 'rm -f "$PID_PATH"' EXIT
    write_status installing "install started"
    if /bin/sh "$INSTALL_SCRIPT" "$@" > "$LOG_PATH" 2>&1; then
      version="$(read_version)"
      write_status done "installed${version:+: $version}"
    else
      rc="$?"
      tail_msg="$(tail -n 3 "$LOG_PATH" 2>/dev/null | tr '\n' ' ' | sed 's/[[:space:]]*$//')"
      write_status failed "exit $rc${tail_msg:+: $tail_msg}"
      exit "$rc"
    fi
  ) >/dev/null 2>&1 &

  echo "$!" > "$PID_PATH"
  write_status installing "install started"
  echo "started"
}

case "${1:-status}" in
  start)
    shift
    start_install "$@"
    ;;
  status)
    if [ -r "$INSTALL_ROOT/meta.json" ]; then
      version="$(read_version)"
      write_status done "installed${version:+: $version}"
    elif is_running; then
      write_status installing "install running"
    elif [ ! -r "$STATUS_PATH" ]; then
      write_status idle "not installed"
    fi
    cat "$STATUS_PATH"
    ;;
  clear)
    rm -f "$STATUS_PATH" "$LOG_PATH" "$PID_PATH"
    write_status idle "not installed"
    cat "$STATUS_PATH"
    ;;
  *)
    echo "usage: openbox-bootstrap {start|status|clear} [--direct|--mirror [prefix]]" >&2
    exit 2
    ;;
esac
EOF

  cat > package/luci-app-openbox/files/usr/share/luci/menu.d/luci-app-openbox-installer.json <<'EOF'
{
	"admin/services/openbox-install": {
		"title": "Open-Box 安装",
		"order": 29,
		"action": { "type": "view", "path": "openbox/install" },
		"depends": { "acl": [ "luci-app-openbox-installer" ] }
	}
}
EOF

  cat > package/luci-app-openbox/files/usr/share/rpcd/acl.d/luci-app-openbox-installer.json <<'EOF'
{
	"luci-app-openbox-installer": {
		"description": "Grant access to Open-Box first-run installer",
		"read": {
			"file": {
				"/opt/open-box/meta.json": [ "read" ],
				"/tmp/openbox-install.log": [ "read" ],
				"/tmp/openbox-install.status": [ "read" ]
			}
		},
		"write": {
			"file": {
				"/usr/bin/openbox-bootstrap": [ "exec" ]
			}
		}
	}
}
EOF

  cat > package/luci-app-openbox/files/www/luci-static/resources/view/openbox/install.js <<'EOF'
'use strict';
'require view';
'require fs';
'require ui';

var BOOTSTRAP = '/usr/bin/openbox-bootstrap';
var META = '/opt/open-box/meta.json';
var LOG = '/tmp/openbox-install.log';
var STATUS = '/tmp/openbox-install.status';

function parseStatus(text) {
	var out = {};
	String(text || '').split(/\n/).forEach(function (line) {
		var idx = line.indexOf('=');
		if (idx > 0) out[line.slice(0, idx)] = line.slice(idx + 1);
	});
	return out;
}

function readInstalled() {
	return fs.read(META).then(function (text) {
		var meta = JSON.parse(text);
		return meta && meta.version ? String(meta.version) : 'installed';
	}).catch(function () {
		return null;
	});
}

function readStatus() {
	return fs.exec(BOOTSTRAP, [ 'status' ]).then(function (res) {
		return parseStatus(res.stdout || '');
	}).catch(function () {
		return { stage: 'idle', message: 'not installed' };
	});
}

function readLog() {
	return fs.read(LOG).then(function (text) {
		var lines = String(text || '').split(/\n/);
		return lines.slice(Math.max(lines.length - 80, 0)).join('\n');
	}).catch(function () {
		return '';
	});
}

function panelUrl() {
	var host = location.hostname || '<router-ip>';
	return 'http://' + host + ':2026';
}

return view.extend({
	load: function () {
		return Promise.all([ readInstalled(), readStatus(), readLog() ]);
	},

	render: function (data) {
		var installed = data[0];
		var status = data[1] || {};
		var logText = data[2] || '';
		var statusEl = E('span', {}, status.message || status.stage || 'not installed');
		var logEl = E('pre', {
			'style': 'max-height:28em;overflow:auto;white-space:pre-wrap;background:#111;color:#ddd;padding:1em;border-radius:6px'
		}, logText || 'No install log yet.');

		function refresh() {
			return Promise.all([ readInstalled(), readStatus(), readLog() ]).then(function (next) {
				var nextInstalled = next[0];
				var nextStatus = next[1] || {};
				statusEl.textContent = nextInstalled
					? '已安装: ' + nextInstalled
					: (nextStatus.message || nextStatus.stage || '未安装');
				logEl.textContent = next[2] || 'No install log yet.';
				if (nextStatus.stage === 'installing' || nextStatus.stage === 'running') {
					window.setTimeout(refresh, 3000);
				}
			});
		}

		function start(args) {
			statusEl.textContent = '正在启动安装...';
			return fs.exec(BOOTSTRAP, [ 'start' ].concat(args)).then(function () {
				ui.addNotification(null, E('p', {}, 'Open-Box 安装已在后台启动。'), 'info');
				return refresh();
			}).catch(function (err) {
				ui.addNotification(null, E('p', {}, '启动安装失败: ' + (err.message || err)), 'error');
				return refresh();
			});
		}

		function clearLog() {
			return fs.exec(BOOTSTRAP, [ 'clear' ]).then(refresh);
		}

		window.setTimeout(refresh, 1000);

		return E('div', {}, [
			E('h2', {}, 'Open-Box 安装'),
			E('p', {}, installed
				? [ 'Open-Box 已安装，面板地址: ', E('a', { href: panelUrl(), target: '_blank', rel: 'noreferrer' }, panelUrl()) ]
				: '固件已内置安装器。点击下方按钮后会在后台下载并校验 Open-Box release 包，安装完成后打开面板设置密码。'),
			E('p', {}, [ E('strong', {}, '状态: '), statusEl ]),
			E('div', { 'style': 'display:flex;gap:.6em;flex-wrap:wrap;margin:1em 0' }, [
				E('button', {
					'class': 'cbi-button cbi-button-apply',
					'click': ui.createHandlerFn(this, function () { return start([ '--mirror' ]); })
				}, '镜像加速安装'),
				E('button', {
					'class': 'cbi-button cbi-button-neutral',
					'click': ui.createHandlerFn(this, function () { return start([ '--direct' ]); })
				}, 'GitHub 直连安装'),
				E('button', {
					'class': 'cbi-button',
					'click': ui.createHandlerFn(this, clearLog)
				}, '清空日志')
			]),
			E('h3', {}, '安装日志'),
			logEl
		]);
	},

	handleSave: null,
	handleSaveApply: null,
	handleReset: null
});
EOF
}
