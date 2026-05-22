# Actions-OpenWrt

基于 GitHub Actions 的 OpenWrt 固件自动化编译项目，支持 ImmortalWrt 和 LEDE 两大主流分支的全流程自动化构建。

## 📋 源码来源

### ImmortalWrt
| 类型 | 地址 |
|------|------|
| 主源码 | [immortalwrt/immortalwrt](https://github.com/immortalwrt/immortalwrt) |
| luci-app-lucky | [gdy666/luci-app-lucky](https://github.com/gdy666/luci-app-lucky) |
| luci-app-mosdns | [sbwml/luci-app-mosdns](https://github.com/sbwml/luci-app-mosdns) |
| luci-app-wechatpush | [tty228/luci-app-wechatpush](https://github.com/tty228/luci-app-wechatpush) |
| passwall | [Openwrt-Passwall/openwrt-passwall](https://github.com/Openwrt-Passwall/openwrt-passwall) |

### LEDE (Lean's OpenWrt)
| 类型 | 地址 |
|------|------|
| 主源码 | [coolsnowwolf/lede](https://github.com/coolsnowwolf/lede) |
| packages | [coolsnowwolf/packages](https://github.com/coolsnowwolf/packages) |
| luci | [coolsnowwolf/luci](https://github.com/coolsnowwolf/luci) |

## 📁 目录结构

```
Actions-OpenWrt/
├── .github/workflows/          # GitHub Actions 工作流
├── config/                     # OpenWrt 配置文件
│   ├── immortalwrt/           # ImmortalWrt 配置
│   └── lede/                   # LEDE 配置
├── scripts/                    # DIY 自定义脚本
│   ├── immortalwrt/           # ImmortalWrt 编译脚本
│   └── lede/                   # LEDE 编译脚本
├── files/                      # 自定义配置文件
└── docs/                       # 项目文档
```

## ⚙️ 工作流说明

### 源码编译工作流

| 工作流 | 说明 | 触发方式 |
|--------|------|----------|
| build_ImmortalWrt_24.10 | ImmortalWrt 24.10 源码编译 | 手动/定时/上游更新 |
| build_ImmortalWrt_25.12 | ImmortalWrt 25.12 源码编译 | 手动/定时/上游更新 |
| build_lede-X64 | LEDE X64 架构源码编译 | 手动/定时/上游更新 |

### ImageBuilder 工作流

| 工作流 | 说明 | 触发方式 |
|--------|------|----------|
| imagebuilder_21.02.7 | ImmortalWrt 21.02.7 ImageBuilder | 手动/定时 |
| imagebuilder_23.05.7 | ImmortalWrt 23.05.7 ImageBuilder | 手动/定时 |
| imagebuilder_24.10.6 | ImmortalWrt 24.10.6 ImageBuilder | 手动/定时 |
| imagebuilder_24.10.4_rockchip | ImmortalWrt 24.10.4 Rockchip ARM64 | 手动/定时 |
| imagebuilder_25.12-SNAPSHOT | ImmortalWrt 25.12 SNAPSHOT ImageBuilder | 手动/定时 |

### 更新检测工作流

| 工作流 | 说明 | 触发方式 |
|--------|------|----------|
| update-checker | 检测上游源码更新 | 每天定时 |
| update-tag-checker | 检测标签更新 | 每天定时 |

## 🏗️ ImageBuilder 编译模式

ImageBuilder 是一种轻量级的固件构建方式，通过预编译的基础镜像配合自定义软件包实现快速固件构建。

### ImageBuilder vs 源码编译

| 对比项 | ImageBuilder | 源码编译 |
|--------|--------------|----------|
| 编译速度 | 10-30 分钟 | 1-6 小时 |
| 灵活性 | 仅添加/删除软件包 | 可深度定制内核/配置 |
| 适用场景 | 快速迭代、版本测试 | 深度定制、特定需求 |
| 系统要求 | 较低 | 较高 |

### 内置软件包

ImageBuilder 工作流默认集成以下软件包：

**基础包**
- luci-app-openclash - OpenClash 客户端
- luci-app-ddns-go - DDNS-GO 动态域名
- luci-app-wechatpush - 微信推送通知
- luci-app-passwall - PassWall 代理
- luci-app-mosdns - DNS 优化
- luci-app-lucky - 幸运抽奖插件
- luci-proto-wireguard - WireGuard 协议
- luci-app-ttyd - 网页终端
- luci-app-attendedsysupgrade - 在线升级
- luci-app-dashboard - 仪表盘

**网络工具**
- xray-core / homeproxy - 代理核心
- ddns-scripts-dnspod - DNSPod DDNS
- ddns-scripts-cloudflare - Cloudflare DDNS
- kmod-nft-socket - NFT socket 扩展

**中文语言包**
- luci-i18n-base-zh-cn
- luci-i18n-firewall-zh-cn
- luci-i18n-ddns-zh-cn
- luci-i18n-package-manager-zh-cn
- luci-i18n-smartdns-zh-cn

### 默认配置修改

所有 ImageBuilder 工作流统一应用以下配置：

```bash
# 禁用不常用的镜像格式
CONFIG_TARGET_ROOTFS_EXT4FS=n
CONFIG_TARGET_EXT4_RESERVED_PCT=0
CONFIG_TARGET_EXT4_BLOCKSIZE_4K=n
CONFIG_TARGET_ISO_IMAGES=n
CONFIG_TARGET_QCOW2_IMAGES=n
CONFIG_TARGET_VDI_IMAGES=n
CONFIG_TARGET_VMDK_IMAGES=n
CONFIG_TARGET_VHDX_IMAGES=n

# 修改根分区大小
CONFIG_TARGET_ROOTFS_PARTSIZE=512

# 修改默认 LAN IP
CONFIG_TARGET_PREINIT_IP="192.168.50.1"
CONFIG_TARGET_PREINIT_BROADCAST="192.168.50.255"
```

## 🚀 使用方法

### 快速开始

1. 点击本仓库上方的 **Use this template** 使用模板创建新仓库
2. 在 GitHub 设置中添加 Personal Access Token（选中 `public_repo`），命名为 `RELEASES_TOKEN`
3. 根据需要修改 `config/` 中的配置文件
4. 手动触发 workflow 或等待定时任务自动编译

### 本地编译

**首次编译（ImmortalWrt）**
```bash
git clone -b openwrt-24.10 --single-branch https://github.com/immortalwrt/immortalwrt
cd immortalwrt
./scripts/feeds update -a && ./scripts/feeds install -a
make menuconfig
make download -j8
make V=s -j1
```

**二次编译**
```bash
cd immortalwrt
git pull && ./scripts/feeds update -a && ./scripts/feeds install -a
make defconfig && make download -j8
make V=s -j$(nproc)
```

### ImageBuilder 本地使用

```bash
# 下载 ImageBuilder
wget https://downloads.immortalwrt.org/releases/24.10.6/targets/x86/64/immortalwrt-imagebuilder-24.10.6-x86-64.Linux-x86_64.tar.zst
tar -I zstd -xf immortalwrt-imagebuilder-24.10.6-x86-64.Linux-x86_64.tar.zst
cd immortalwrt-imagebuilder-24.10.6-x86-64.Linux-x86_64

# 编译固件
make image PACKAGES="luci luci-app-openclash luci-i18n-base-zh-cn"
```

## 🌐 DNS 协议配置

### 国内 DNS

| 服务商 | IPv4 | DoH | DoT |
|--------|------|-----|-----|
| 阿里 | 223.5.5.5 / 223.6.6.6 | https://dns.alidns.com/dns-query | tls://dns.alidns.com |
| 腾讯 | 119.29.29.29 | https://doh.pub/dns-query | tls://dot.pub |
| 360 | 101.226.4.6 | https://doh.360.cn | tls://dot.360.cn |
| 百度 | 180.76.76.76 | - | - |

### 国外 DNS

| 服务商 | IPv4 | DoH | DoT |
|--------|------|-----|-----|
| Google | 8.8.8.8 / 8.8.4.4 | https://dns.google/dns-query | tls://dns.google |
| Cloudflare | 1.1.1.1 / 1.0.0.1 | https://cloudflare-dns.com/dns-query | tls://1dot1dot1dot1.cloudflare-dns.com |
| Quad9 | 9.9.9.9 | https://dns.quad9.net/dns-query | tls://dns.quad9.net |
| AdGuard | 94.140.14.14 | https://dns.adguard.com/dns-query | tls://dns.adguard-dns.com |
| NextDNS | - | https://dns.nextdns.io | - |
| DNS.SB | 185.222.222.222 | https://doh.sb/dns-query | tls://dot.sb |

### DNS-over-QUIC

| 服务商 | 地址 |
|--------|------|
| AdGuard | quic://dns.adguard-dns.com |
| NextDNS | quic://dns.nextdns.io |

## 🙏 致谢

- [P3TERX](https://github.com/P3TERX/Actions-OpenWrt) - Actions-OpenWrt 原始项目
- [id77](https://github.com/id77/OpenWrt-K2P-firmware) - Release 相关参考
- [ncipollo](https://github.com/ncipollo/release-action) - Release Action 参考
- [Microsoft](https://www.microsoft.com) / [Azure](https://azure.microsoft.com)
- [GitHub](https://github.com) / [GitHub Actions](https://github.com/features/actions)
- [tmate](https://github.com/tmate-io/tmate) / [mxschmitt/action-tmate](https://github.com/mxschmitt/action-tmate)
- [OpenWrt](https://github.com/openwrt/openwrt) / [Lean's OpenWrt](https://github.com/coolsnowwolf/lede)
