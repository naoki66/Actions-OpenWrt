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

## ⚙️ 工作流说明

| 工作流 | 说明 |
|--------|------|
| build_ImmortalWrt_24.10 | ImmortalWrt 24.10 版本构建 |
| build_ImmortalWrt_25.12 | ImmortalWrt 25.12 版本构建 |
| build_lede-X64 | LEDE X64 架构构建 |

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
