# Actions-OpenWrt

基于 GitHub Actions 的 OpenWrt 固件自动化构建项目，支持 ImmortalWrt、LEDE 源码编译，以及 ImmortalWrt ImageBuilder 快速构建。项目适合用于固定配置的路由器固件自动编译、上游更新检测和 Release 发布。

## 项目能力

- 自动检测上游源码或 ImageBuilder 版本变化，并按需触发构建。
- 支持 ImmortalWrt 24.10、ImmortalWrt 25.12、LEDE X64 源码编译。
- 支持多个 ImmortalWrt ImageBuilder 版本和 Rockchip 目标。
- 通过 `config/` 保存编译配置，通过 `scripts/` 保存 feeds 和系统默认配置修改。
- 构建完成后上传固件产物，并创建 GitHub Release。

## 源码与扩展来源

| 类型 | 仓库 |
| --- | --- |
| ImmortalWrt | [immortalwrt/immortalwrt](https://github.com/immortalwrt/immortalwrt) |
| LEDE | [coolsnowwolf/lede](https://github.com/coolsnowwolf/lede) |
| luci-app-lucky | [gdy666/luci-app-lucky](https://github.com/gdy666/luci-app-lucky) |
| luci-app-mosdns | [sbwml/luci-app-mosdns](https://github.com/sbwml/luci-app-mosdns) |
| luci-app-wechatpush | [tty228/luci-app-wechatpush](https://github.com/tty228/luci-app-wechatpush) |
| passwall | [Openwrt-Passwall/openwrt-passwall](https://github.com/Openwrt-Passwall/openwrt-passwall) |
| rtp2httpd | [stackia/rtp2httpd](https://github.com/stackia/rtp2httpd) |

## 目录结构

```text
Actions-OpenWrt/
├── .github/workflows/          # GitHub Actions 工作流
├── config/                     # OpenWrt .config 配置
│   ├── immortalwrt/            # ImmortalWrt 配置
│   └── lede/                   # LEDE 配置
├── scripts/                    # 自定义 feeds 和系统配置脚本
│   ├── immortalwrt/
│   └── lede/
├── files/                      # 固件内置文件
└── docs/                       # 补充文档
```

## 工作流说明

### 源码编译

| 工作流文件 | 构建目标 | 触发方式 |
| --- | --- | --- |
| `build_ImmortalWrt_24.10.yml` | ImmortalWrt 24.10 x86_64 | 手动、上游更新 |
| `build_ImmortalWrt_25.12.yml` | ImmortalWrt 25.12 x86_64 | 手动、上游更新 |
| `build_lede-X64.yml` | LEDE x86_64 | 手动、上游更新 |
| `update-checker.yml` | 检测 ImmortalWrt / LEDE 上游提交 | 定时、手动 |

### ImageBuilder

| 工作流文件 | 构建目标 | 触发方式 |
| --- | --- | --- |
| `imagebuilder_21.02.7.yml` | ImmortalWrt 21.02.7 x86_64 | 手动、版本检测 |
| `imagebuilder_23.05.7.yml` | ImmortalWrt 23.05.7 x86_64 | 手动、版本检测 |
| `imagebuilder_24.10.6.yml` | ImmortalWrt 24.10.6 x86_64 | 手动、版本检测 |
| `imagebuilder_24.10.4_rockchip.yml` | ImmortalWrt 24.10.4 Rockchip ARM64 | 手动、版本检测 |
| `imagebuilder_25.12.0.yml` | ImmortalWrt 25.12.0 x86_64 | 手动、版本检测 |
| `imagebuilder-update-checker.yml` | 检测 ImageBuilder `version.buildinfo` | 定时、手动 |

## 快速使用

1. 使用本仓库作为模板，创建自己的固件构建仓库。
2. 在仓库 `Settings -> Actions -> General` 中启用工作流读写权限，确保 Release、缓存和清理步骤可以正常运行。
3. 按目标平台修改 `config/` 中的 `.config` 文件。
4. 按需求修改 `scripts/*/*-diy-part1.sh` 添加 feeds 或第三方包，修改 `*-diy-part2.sh` 调整默认 IP、DHCP、IPv6 等系统配置。
5. 进入 GitHub Actions 页面，手动运行目标工作流，或等待更新检测工作流自动触发。

可选 Secret：

| Secret | 用途 |
| --- | --- |
| `PUSHPLUS_TOKEN` | ImageBuilder 构建完成后的 Pushplus 通知。未配置时只影响通知。 |

Release 发布和工作流触发默认使用 GitHub 自动注入的 `GITHUB_TOKEN`。

## 常用定制入口

| 需求 | 修改位置 |
| --- | --- |
| 更换固件目标或软件包 | `config/immortalwrt/*.config`、`config/lede/*.config` |
| 添加 feeds | `scripts/immortalwrt/*-diy-part1.sh`、`scripts/lede/lede-diy-part1.sh` |
| 修改默认 LAN IP | `scripts/*/*-diy-part2.sh` |
| 调整 DHCP、IPv6 默认配置 | `scripts/lede/lede-diy-part2.sh` |
| 添加固件内置文件 | `files/lede/`、`files/immortalwrt/` |
| 调整构建产物、Release 和清理逻辑 | `.github/workflows/*.yml` |

当前默认 LAN IP 主要调整为 `192.168.50.1`。LEDE 脚本还会删除 IPv6 ULA 前缀，并将 DHCP 地址池起始值设置为 `50`。

## 固件文件隔离

OpenWrt 会把源码目录下的 `files/` 作为固件根目录叠加到最终镜像。为避免 LEDE 和 ImmortalWrt 互相引入不兼容配置，本仓库按构建分支隔离内置文件：

| 目录 | 注入目标 |
| --- | --- |
| `files/lede/` | 仅注入 LEDE 源码编译工作流 |
| `files/immortalwrt/` | 仅注入 ImmortalWrt 源码编译工作流 |

目录内部结构要按固件根目录写。例如只给 LEDE 加入 `/etc/config/google_fu_mode`：

```text
files/lede/etc/config/google_fu_mode
```

只给 ImmortalWrt 加入同类配置时，放到：

```text
files/immortalwrt/etc/config/google_fu_mode
```

不要把通用配置直接放在仓库根部的 `files/etc/...`。如果确实需要两边共用，分别复制到 `files/lede/` 和 `files/immortalwrt/`，这样后续仍能独立调整。

## 增加软件包

### 源码编译工作流

源码编译适合添加 feeds、克隆第三方源码包，或启用需要重新编译的内核模块和 LuCI 应用。

1. 在对应的 `*-diy-part1.sh` 中添加软件源或直接克隆软件包。

```bash
# 添加 feed
echo 'src-git myfeed https://github.com/user/openwrt-packages.git;main' >> feeds.conf.default

# 或直接克隆到 package 目录
git clone --depth 1 https://github.com/user/luci-app-example.git package/luci-app-example
```

2. 在对应的 `.config` 中启用软件包。

```bash
CONFIG_PACKAGE_luci-app-example=y
CONFIG_PACKAGE_luci-i18n-example-zh-cn=y
```

3. 如需从本地菜单生成配置，可在 OpenWrt 源码目录执行：

```bash
make menuconfig
./scripts/diffconfig.sh > seed.config
```

然后把需要的 `CONFIG_PACKAGE_*` 选项合并到本仓库 `config/` 下对应的配置文件。

### ImageBuilder 工作流

ImageBuilder 适合添加上游仓库已经提供的预编译包，或下载兼容目标架构的 `.ipk` 后一起打包。

1. 添加官方仓库内已有的软件包：修改对应 `imagebuilder_*.yml` 中 `make image` 的 `PACKAGES` 参数。

```bash
make image PACKAGES="luci luci-app-ddns luci-i18n-ddns-zh-cn"
```

2. 删除默认包：在包名前加 `-`。

```bash
make image PACKAGES="luci -dnsmasq dnsmasq-full"
```

3. 添加第三方 `.ipk`：先在工作流中下载到 ImageBuilder 的 `packages/` 目录，再在 `PACKAGES` 中写入包名。

```bash
mkdir -p ./packages
wget -P ./packages https://example.com/path/luci-app-example_1.0.0_all.ipk
make image PACKAGES="luci luci-app-example"
```

注意事项：

- 软件包名称以 OpenWrt 包名为准，不一定等同于 GitHub 仓库名。
- LuCI 应用通常需要同时添加主包和中文语言包，例如 `luci-app-example`、`luci-i18n-example-zh-cn`。
- ImageBuilder 的 `.ipk` 必须匹配 OpenWrt/ImmortalWrt 版本、目标架构和依赖 ABI；不匹配时应改用源码编译。
- 增加包后如果构建失败，优先查看日志中的 `Unknown package`、`Cannot satisfy dependencies` 和架构不匹配提示。

## ImageBuilder 说明

ImageBuilder 使用上游预编译基础镜像，只重新打包指定软件包，速度通常快于完整源码编译。它适合快速更新软件包、验证版本和生成常用 x86_64 固件；如果需要修改内核、深度调整编译选项或解决源码级依赖问题，应使用源码编译工作流。

| 对比项 | ImageBuilder | 源码编译 |
| --- | --- | --- |
| 构建速度 | 通常 10-30 分钟 | 通常 1-6 小时 |
| 定制深度 | 添加或删除软件包、修改基础配置 | 可修改内核、feeds、源码和完整 `.config` |
| 适用场景 | 快速迭代、日常更新 | 深度定制、排查源码问题 |

ImageBuilder 工作流常见内置组件包括 OpenClash、PassWall、mosdns、ddns-go、wechatpush、lucky、WireGuard、ttyd、dashboard、homeproxy、xray-core 和常用中文语言包。具体软件包以对应工作流中的 `PACKAGES` 参数为准。

## 本地编译参考

首次编译 ImmortalWrt：

```bash
git clone -b openwrt-24.10 --single-branch https://github.com/immortalwrt/immortalwrt
cd immortalwrt
./scripts/feeds update -a && ./scripts/feeds install -a
make menuconfig
make download -j8
make V=s -j1
```

二次编译：

```bash
cd immortalwrt
git pull
./scripts/feeds update -a && ./scripts/feeds install -a
make defconfig
make download -j8
make V=s -j$(nproc)
```

本地使用 ImageBuilder：

```bash
wget https://downloads.immortalwrt.org/releases/24.10.6/targets/x86/64/immortalwrt-imagebuilder-24.10.6-x86-64.Linux-x86_64.tar.zst
tar -I zstd -xf immortalwrt-imagebuilder-24.10.6-x86-64.Linux-x86_64.tar.zst
cd immortalwrt-imagebuilder-24.10.6-x86-64.Linux-x86_64
make image PACKAGES="luci luci-app-openclash luci-i18n-base-zh-cn"
```

## 常用 DNS 配置

以下地址可用于 mosdns、SmartDNS、OpenClash、PassWall 或系统 DNS 转发配置。不同地区网络质量差异较大，建议按实际延迟、稳定性和解析结果选择。

### 国内 DNS

| 服务商 | IPv4 | DoH | DoT |
| --- | --- | --- | --- |
| 阿里 DNS | `223.5.5.5` / `223.6.6.6` | `https://dns.alidns.com/dns-query` | `tls://dns.alidns.com` |
| 腾讯 DNSPod | `119.29.29.29` | `https://doh.pub/dns-query` | `tls://dot.pub` |
| 360 DNS | `101.226.4.6` | `https://doh.360.cn` | `tls://dot.360.cn` |
| 百度 DNS | `180.76.76.76` | - | - |

### 国外 DNS

| 服务商 | IPv4 | DoH | DoT |
| --- | --- | --- | --- |
| Google | `8.8.8.8` / `8.8.4.4` | `https://dns.google/dns-query` | `tls://dns.google` |
| Cloudflare | `1.1.1.1` / `1.0.0.1` | `https://cloudflare-dns.com/dns-query` | `tls://1dot1dot1dot1.cloudflare-dns.com` |
| Quad9 | `9.9.9.9` | `https://dns.quad9.net/dns-query` | `tls://dns.quad9.net` |
| AdGuard | `94.140.14.14` | `https://dns.adguard.com/dns-query` | `tls://dns.adguard-dns.com` |
| NextDNS | - | `https://dns.nextdns.io` | - |
| DNS.SB | `185.222.222.222` | `https://doh.sb/dns-query` | `tls://dot.sb` |

### DNS-over-QUIC

| 服务商 | 地址 |
| --- | --- |
| AdGuard | `quic://dns.adguard-dns.com` |
| NextDNS | `quic://dns.nextdns.io` |

## 故障排查

| 问题 | 处理建议 |
| --- | --- |
| 构建超时 | 减少软件包，或先使用 `make V=s -j1` 定位失败点。 |
| 依赖下载失败 | 重试工作流，或检查上游下载源、GitHub 网络和 Go 代理设置。 |
| Release 创建失败 | 检查 Actions 读写权限，以及工作流中的 `contents: write` 权限。 |
| 推送通知失败 | 检查 `PUSHPLUS_TOKEN` 是否配置正确；该失败不影响固件产物。 |
| 固件启动后 IP 不符合预期 | 检查对应 `*-diy-part2.sh` 和 ImageBuilder 工作流中的默认 IP 修改。 |

## 参考项目

- [P3TERX/Actions-OpenWrt](https://github.com/P3TERX/Actions-OpenWrt)
- [coolsnowwolf/lede](https://github.com/coolsnowwolf/lede)
- [immortalwrt/immortalwrt](https://github.com/immortalwrt/immortalwrt)
- [OpenWrt 官方文档](https://openwrt.org/docs/start)
- [GitHub Actions 文档](https://docs.github.com/actions)
