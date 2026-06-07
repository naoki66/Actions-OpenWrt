# Actions-OpenWrt 项目文档

## 1. 项目概述

`Actions-OpenWrt` 是一个基于 **GitHub Actions** 的 OpenWrt 固件自动化编译项目。该项目实现了从源码获取、自定义配置到固件编译和发布的全流程自动化，同时支持 ImmortalWrt ImageBuilder 快速构建。

### 1.1 项目定位

| 属性 | 说明 |
|------|------|
| **项目类型** | CI/CD 自动化流水线 |
| **目标平台** | OpenWrt 路由器固件 |
| **核心能力** | 自动化检测上游更新、编译固件、发布版本 |
| **支持源码** | ImmortalWrt、LEDE (Lean's OpenWrt) |
| **快速构建** | ImmortalWrt ImageBuilder |

### 1.2 主要特性

- 🔄 **自动更新检测**：定时检查上游源码仓库和 ImageBuilder 更新，自动触发编译
- 🛠️ **自定义配置**：支持通过 DIY 脚本自定义 feeds 和系统配置
- 📦 **多版本支持**：同时支持 ImmortalWrt 和 LEDE 两大主流 OpenWrt 分支
- 🚀 **自动化发布**：编译完成后自动创建 GitHub Release
- 🧹 **自动清理**：定期清理旧工作流记录和旧版本
- ⚡ **快速构建**：支持 ImageBuilder 快速打包预编译固件

---

## 2. 项目架构

### 2.1 整体架构图

```
┌─────────────────────────────────────────────────────────────────┐
│                    GitHub Actions 工作流                        │
├─────────────────────────────────────────────────────────────────┤
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐     │
│  │ update-    │───▶│ build_       │───▶│ imagebuilder│     │
│  │ checker   │    │ ImmortalWrt│    │ _*.yml     │     │
│  └──────────────┘    │ /lede   │    │              │     │
│  ┌──────────────┐    │ (24.10/25.12│    │              │     │
│  │ imagebuilder │───▶│              │    │              │     │
│  │ -checker    │    │              │    │              │     │
│  └──────────────┘    └──────────────┘    └──────────────┘     │
│         │                  │                  │                │
│         ▼                  ▼                  ▼                │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐     │
│  │ 检测上游更新  │    │ 克隆源码     │    │ 下载预编译    │     │
│  │ 计算哈希对比  │    │ 更新feeds    │    │ ImageBuilder│     │
│  └──────────────┘    └──────────────┘    └──────────────┘     │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
                    ┌──────────────┐
                    │ GitHub Release│
                    └──────────────┘
```

### 2.2 目录结构

```
Actions-OpenWrt/
├── .github/
│   └── workflows/           # GitHub Actions 工作流配置
│       ├── build_ImmortalWrt_24.10.yml
│       ├── build_ImmortalWrt_25.12.yml
│       ├── build_lede-X64.yml
│       ├── imagebuilder_21.02.7.yml
│       ├── imagebuilder_23.05.7.yml
│       ├── imagebuilder_24.10.4_rockchip.yml
│       ├── imagebuilder_24.10.6.yml
│       ├── imagebuilder_25.12.0.yml
│       ├── update-checker.yml              # 更新检测工作流
│       └── imagebuilder-update-checker.yml  # ImageBuilder更新检测
├── config/
│   ├── immortalwrt/                         # ImmortalWrt 配置文件
│   │   ├── ImmortalWrt-24.10-x64.config
│   │   ├── ImmortalWrt-25.12-x64.config
│   │   └── ImmortalWrt_RFastRhino_R68S.config
│   └── lede/                               # LEDE 配置文件
│       ├── lede-x64.config
│       └── lede-R68S.config
├── scripts/
│   ├── immortalwrt/                        # ImmortalWrt DIY 脚本
│   │   ├── ImmortalWrt-diy-part1.sh
│   │   ├── ImmortalWrt-diy-part2.sh
│   │   ├── ImmortalWrt25-diy-part1.sh
│   │   └── ImmortalWrt25-diy-part2.sh
│   └── lede/                               # LEDE DIY 脚本
│       ├── lede-diy-part1.sh
│       ├── lede-diy-part2.sh
│       └── lede-iptv.sh
├── files/
│   ├── immortalwrt/etc/config/              # ImmortalWrt 自定义配置
│   └── lede/etc/config/google_fu_mode      # LEDE 自定义配置
├── docs/
│   ├── CODE_WIKI.md                        # 项目开发文档
│   └── depends-ubuntu                       # Ubuntu 依赖说明
└── README.md                               # 项目说明
```

### 2.3 模块职责划分

| 模块 | 职责 | 关键文件 |
|------|------|----------|
| **更新检测模块** | 定时检查上游源码更新，触发编译 | `update-checker.yml`, `imagebuilder-update-checker.yml` |
| **源码构建模块** | 克隆源码、编译固件 | `build_*.yml` |
| **ImageBuilder 模块** | 下载 ImageBuilder、打包固件 | `imagebuilder_*.yml` |
| **自定义模块** | 添加 feeds、修改系统配置 | `*-diy-part1.sh`, `*-diy-part2.sh` |
| **发布模块** | 创建 Release、上传固件 | GitHub Actions 内置步骤 |
| **清理模块** | 清理旧工作流和版本 | 工作流内置步骤 |

---

## 3. 核心文件详解

### 3.1 工作流配置文件

#### 3.1.1 build_ImmortalWrt_24.10.yml

**功能定位**：构建 ImmortalWrt 24.10 X64 架构固件的核心工作流

**触发机制**：
- `repository_dispatch`: 接收 `immortalwrt-24-10-group-update` 事件（由 update-checker 触发）
- `workflow_dispatch`: 手动触发

**关键环境变量**：

| 变量 | 值 | 说明 |
|------|----|------|
| `REPO_URL` | `https://github.com/immortalwrt/immortalwrt` | 源码仓库地址 |
| `REPO_BRANCH` | `openwrt-24.10` | 源码分支 |
| `CONFIG_FILE` | `config/immortalwrt/ImmortalWrt-24.10-x64.config` | 配置文件路径 |
| `DIY_P1_SH` | `scripts/immortalwrt/ImmortalWrt-diy-part1.sh` | 第一阶段DIY脚本 |
| `DIY_P2_SH` | `scripts/immortalwrt/ImmortalWrt-diy-part2.sh` | 第二阶段DIY脚本 |
| `UPLOAD_FIRMWARE` | `true` | 是否上传固件产物 |
| `UPLOAD_RELEASE` | `true` | 是否创建 Release |
| `TZ` | `Asia/Shanghai` | 时区设置 |

**工作流阶段**：

| 阶段 | 步骤 | 说明 |
|------|------|------|
| 1️⃣ 检出仓库 | `actions/checkout@v6` | 获取项目文件 |
| 2️⃣ 准备环境 | 安装依赖包 | 安装编译所需的所有依赖（包括 zstd 等） |
| 3️⃣ 克隆源码 | `git clone` | 克隆 ImmortalWrt 源码到 `/mnt/workdir` |
| 4️⃣ 自定义 feeds | 执行 `DIY_P1_SH` | 添加第三方 feeds |
| 5️⃣ 更新安装 feeds | `./scripts/feeds update/install` | 更新并安装所有 feeds |
| 6️⃣ 自定义配置 | 执行 `DIY_P2_SH` | 修改系统默认配置 |
| 7️⃣ 生成更新日志 | GitHub API | 获取上游最近7天更新 |
| 8️⃣ 下载源码包 | `make download` | 预下载所有依赖包 |
| 9️⃣ 编译固件 | `make V=s -j2` 或 `make V=s -j1` | 编译 OpenWrt 固件 |
| 🔟 整理输出 | 清理 packages | 只保留固件文件 |
| 1️⃣1️⃣ 计算耗时 | 时间戳对比 | 统计编译总耗时 |
| 1️⃣2️⃣ 上传产物 | `actions/upload-artifact@v7` | 上传到 GitHub Artifacts |
| 1️⃣3️⃣ 创建 Release | `softprops/action-gh-release@v3` | 发布到 GitHub Release |
| 1️⃣4️⃣ 清理旧记录 | 自定义脚本 | 删除3天前的工作流记录 |
| 1️⃣5️⃣ 清理旧版本 | 自定义脚本 | 保留最近8个版本 |
| 1️⃣6️⃣ 缓存更新哈希 | `actions/cache/save@v5` | 保存上游更新的提交哈希 |

#### 3.1.2 imagebuilder_24.10.6.yml

**功能定位**：使用 ImmortalWrt ImageBuilder 快速构建固件

**触发机制**：
- `repository_dispatch`: 接收 `ImageBuilder_updated` 事件
- `workflow_dispatch`: 手动触发
- `schedule`: 每月 2 日 05:45（中国时间）

**与源码构建差异**：

| 差异点 | 源码编译 | ImageBuilder |
|--------|----------|-------------|
| 构建时间 | 1-6小时 | 10-30分钟 |
| 定制深度 | 内核、源码修改 | 只增减软件包 |
| 适用场景 | 深度定制 | 日常更新 |

**关键步骤**：
1. 检查 `version.buildinfo` 变化
2. 从多镜像源下载 ImageBuilder
3. 修改 ImageBuilder 配置（如默认 IP、根分区大小
4. 下载第三方 `.ipk` 软件包
5. 使用 `make image PACKAGES="..."` 打包固件
6. 上传固件、创建 Release

#### 3.1.3 update-checker.yml

**功能定位**：定时检测上游源码更新，触发自动编译

**触发机制**：
- `workflow_dispatch`: 手动触发
- `schedule`: 每天 23:40（中国时间）

**核心逻辑**：

1. **分组检测**：将源码分为三组
   - `immortalwrt-24-10-group
   - `immortalwrt-25-12-group
   - `lede-group`

2. **哈希计算**：
   - 获取每个主源码仓库最新 commit 哈希

3. **更新判断**：
   - 从缓存读取上次的哈希
   - 对比新旧哈希，若不同则触发构建

4. **触发构建**：
   - 通过 `peter-evans/repository-dispatch@v4` 发送事件
   - 事件类型：`immortalwrt-24-10-group-update` 等

#### 3.1.4 imagebuilder-update-checker.yml

**功能定位**：检测 ImageBuilder 的 `version.buildinfo` 文件变化并触发编译

**监控的 ImageBuilder 版本**：
- ImmortalWrt 21.02.7 (x86_64)
- ImmortalWrt 23.05.7 (x86_64)
- ImmortalWrt 24.10.4 (Rockchip ARMv8)
- ImmortalWrt 24.10.6 (x86_64)
- ImmortalWrt 25.12.0 (x86_64)

**检测机制**：
- 每天 04:30（中国时间）定时检查
- 对比 `version.buildinfo` 文件的 SHA256 哈希值
- 若有变化则触发对应 ImageBuilder 构建

---

### 3.2 DIY 脚本详解

#### 3.2.1 lede-diy-part1.sh

**功能定位**：第一阶段自定义脚本，负责添加 feeds 和第三方软件包

**核心操作**：

```bash
# 添加 helloworld feed（包含 v2ray 等工具）
echo 'src-git helloworld https://github.com/fw876/helloworld.git' >>feeds.conf.default

# 克隆 luci-app-lucky（幸运抽奖插件）
git clone https://github.com/gdy666/luci-app-lucky.git package/lucky

# 克隆 luci-app-wechatpush（微信推送插件）
git clone https://github.com/tty228/luci-app-wechatpush package/luci-app-wechatpush
```

**执行时机**：在 `./scripts/feeds update` 之前执行

**设计意图**：添加官方 feeds 之外的第三方软件源，扩展固件功能

#### 3.2.2 lede-diy-part2.sh

**功能定位**：第二阶段自定义脚本，负责修改系统默认配置

**核心操作**：

| 操作 | 命令 | 说明 |
|------|------|------|
| 修改默认 IP | `sed -i 's/192.168.1.1/192.168.50.1/g'` | 将 LAN 口默认 IP 改为 192.168.50.1 |
| 修改日期格式 | `sed -i 's/os.date(/&"%Y-%m-%d %H:%M:%S"/'` | 自定义首页显示的日期格式 |
| 删除 ULA 前缀 | `uci delete network.globals.ula_prefix` | 移除 IPv6 ULA 前缀配置 |
| 设置 DHCP 起始 | `uci set dhcp.lan.start='50'` | 设置 DHCP 地址池起始为 50 |
| 设置 IPv6 分配 | `uci set network.lan.ip6assign='64'` | 设置 IPv6 子网掩码长度 |

**执行时机**：在 `./scripts/feeds install` 之后，`make defconfig` 之前

#### 3.2.3 ImmortalWrt-diy-part1.sh

**功能定位**：ImmortalWrt 的第一阶段自定义脚本

**核心操作**：

```bash
# 克隆 luci-app-lucky（幸运抽奖插件）
git clone --depth 1 https://github.com/gdy666/luci-app-lucky.git package/lucky

# 添加 nikki feed（包含额外插件）
echo "src-git nikki https://github.com/nikkinikki-org/OpenWrt-nikki.git;main" >> "feeds.conf.default"

# 添加 rtp2httpd feed（RTSP 转 HTTP 工具）
echo "src-git rtp2httpd https://github.com/stackia/rtp2httpd.git;main" >> "feeds.conf.default"
```

**设计特点**：使用 `--depth 1` 进行浅克隆，加快克隆速度

---

### 3.3 配置文件说明

#### 3.3.1 配置文件列表

| 文件名 | 对应源码 | 适用平台 |
|--------|----------|----------|
| `lede-x64.config` | LEDE | x86_64 |
| `lede-R68S.config` | LEDE | Rockchip R68S |
| `ImmortalWrt-24.10-x64.config` | ImmortalWrt 24.10 | x86_64 |
| `ImmortalWrt-25.12-x64.config` | ImmortalWrt 25.12 | x86_64 |
| `ImmortalWrt_RFastRhino_R68S.config` | ImmortalWrt | Rockchip R68S |

#### 3.3.2 files 目录

项目按构建目标隔离内置配置文件，避免互相污染：
- `files/lede/`: 只用于 LEDE 源码编译
- `files/immortalwrt/`: 只用于 ImmortalWrt 源码编译

---

## 4. 依赖关系

### 4.1 上游源码依赖

| 源码类型 | LEDE 分支 | ImmortalWrt 分支 |
|----------|-----------|------------------|
| 主源码 | [coolsnowwolf/lede](https://github.com/coolsnowwolf/lede) | [immortalwrt/immortalwrt](https://github.com/immortalwrt/immortalwrt) |
| packages | [coolsnowwolf/packages](https://github.com/coolsnowwolf/packages) | [immortalwrt/packages](https://github.com/immortalwrt/packages) |
| luci | [coolsnowwolf/luci](https://github.com/coolsnowwolf/luci) | [immortalwrt/luci](https://github.com/immortalwrt/luci) |

### 4.2 第三方软件包依赖

| 软件包 | 源码地址 | 功能 |
|--------|----------|------|
| luci-app-lucky | [gdy666/luci-app-lucky](https://github.com/gdy666/luci-app-lucky) | 幸运抽奖插件 |
| luci-app-wechatpush | [tty228/luci-app-wechatpush](https://github.com/tty228/luci-app-wechatpush) | 微信推送通知 |
| helloworld | [fw876/helloworld](https://github.com/fw876/helloworld) | V2Ray 等网络工具 |
| OpenWrt-nikki | [nikkinikki-org/OpenWrt-nikki](https://github.com/nikkinikki-org/OpenWrt-nikki) | 额外插件集合 |
| rtp2httpd | [stackia/rtp2httpd](https://github.com/stackia/rtp2httpd) | RTSP 转 HTTP |
| luci-app-mosdns | [sbwml/luci-app-mosdns](https://github.com/sbwml/luci-app-mosdns) | MosDNS DNS 分流 |
| openwrt-passwall | [Openwrt-Passwall/openwrt-passwall](https://github.com/Openwrt-Passwall/openwrt-passwall) | PassWall 网络工具 |

### 4.3 GitHub Actions 依赖

| Action | 版本 | 用途 |
|--------|------|------|
| `actions/checkout` | v6 | 检出仓库代码 |
| `actions/upload-artifact` | v7 | 上传构建产物 |
| `actions/cache` | v5 | 缓存 commit 哈希和 version.buildinfo |
| `softprops/action-gh-release` | v3 | 创建 GitHub Release |
| `peter-evans/repository-dispatch` | v4 | 触发仓库事件 |

### 4.4 系统依赖（Ubuntu 22.04）

编译 OpenWrt 需要安装以下依赖包：

```bash
# 基础编译工具
build-essential autoconf automake bison flex gcc-multilib g++-multilib

# 工具链
binutils gettext libtool make patch pkgconf

# 库依赖
libc6-dev-i386 libelf-dev libglib2.0-dev libgmp3-dev libmpc-dev libmpfr-dev
libncurses5-dev libncursesw5-dev libreadline-dev libssl-dev libyaml-dev zstd

# 辅助工具
git curl wget rsync subversion unzip zip p7zip p7zip-full
scons ninja-build cmake clang llvm lld
squashfs-tools genisoimage device-tree-compiler
python3 python3-pyelftools python3-setuptools python3-ply python3-docutils
ack antlr3 asciidoc autopoint ecj fastjar haveged help2man intltool
lib32gcc-s1 libtool mkisofs msmtp nano qemu-utils re2c swig texinfo uglifyjs
upx-ucl vim xmlto xxd zlib1g-dev
```

---

## 5. 项目运行方式

### 5.1 前提条件

1. **GitHub 账号**：需要拥有 GitHub 账号
2. **仓库模板**：使用此仓库模板创建自己的仓库
3. **Actions 权限**：在仓库 Settings → Actions → General 中允许 workflow 读写仓库内容
4. **Secrets 配置**：
   - `PUSHPLUS_TOKEN`（可选）: 用于 Pushplus 推送通知

### 5.2 配置步骤

1. **配置 Secrets**：
   - 进入仓库 Settings → Secrets and variables → Actions
   - （可选）添加 `PUSHPLUS_TOKEN`，值为 Pushplus token

2. **自定义配置**：
   - 修改 `config/` 目录下对应配置文件
   - 修改 `scripts/` 目录下对应 DIY 脚本
   - 修改 `files/` 目录下内置配置文件

### 5.3 触发方式

#### 方式一：自动触发（上游更新）

`update-checker.yml` 和 `imagebuilder-update-checker.yml` 每天定时运行：
- 检测上游仓库是否有新提交或 ImageBuilder 是否有更新
- 若有更新，自动触发对应构建工作流

#### 方式二：手动触发

1. 进入仓库 Actions 页面
2. 选择目标工作流（如 "构建ImmortalWrt-24.10-X64固件"）
3. 点击 "Run workflow"
4. 选择分支后点击 "Run workflow"

#### 方式三：定时触发（可选）

取消工作流配置中的注释：

```yaml
# schedule:
#   - cron: '20 16 */7 * *'  # 每 7 天北京时间 00:20
```

### 5.4 本地编译（调试用）

**首次编译 ImmortalWrt**：

```bash
git clone -b openwrt-24.10 --single-branch https://github.com/immortalwrt/immortalwrt
cd immortalwrt
./scripts/feeds update -a && ./scripts/feeds install -a
make menuconfig
make download -j8
make V=s -j1
```

**二次编译**：

```bash
cd immortalwrt
git pull
./scripts/feeds update -a && ./scripts/feeds install -a
make defconfig
make download -j8
make V=s -j$(nproc)
```

**本地使用 ImageBuilder**：

```bash
wget https://downloads.immortalwrt.org/releases/24.10.6/targets/x86/64/immortalwrt-imagebuilder-24.10.6-x86-64.Linux-x86_64.tar.zst
tar -I zstd -xf immortalwrt-imagebuilder-24.10.6-x86-64.Linux-x86_64.tar.zst
cd immortalwrt-imagebuilder-24.10.6-x86-64.Linux-x86_64
make image PACKAGES="luci luci-app-openclash luci-i18n-base-zh-cn"
```

---

## 6. 工作流执行流程

### 6.1 更新检测流程

```
┌─────────────────────────────────────────────────────────────┐
│                    update-checker 工作流                    │
├─────────────────────────────────────────────────────────────┤
│  定时触发 (每天 23:40)                                    │
│       │                                                     │
│       ▼                                                     │
│  ┌──────────────┐                                           │
│  │ 恢复缓存     │ ← 获取上次保存的 commit 哈希                │
│  └──────┬───────┘                                           │
│         │                                                     │
│         ▼                                                     │
│  ┌──────────────┐                                           │
│  │ 获取最新哈希  │ ← 获取主源码仓库最新 commit              │
│  └──────┬───────┘                                           │
│         │                                                     │
│         ▼                                                     │
│  ┌──────────────┐                                           │
│  │ 对比哈希     │                                           │
│  └──────┬───────┘                                           │
│         │                                                     │
│    ┌────┴────┐                                              │
│    │         │                                              │
│   相同      不同                                            │
│    │         │                                              │
│    ▼         ▼                                              │
│  结束    ┌──────────────┐                                   │
│          │ 触发构建     │ ← repository-dispatch                 │
│          └──────┬───────┘                                   │
│                 │                                           │
│                 ▼                                           │
│          ┌──────────────┐                                   │
│          │ 保存新哈希   │ ← 更新缓存                         │
│          └──────────────┘                                   │
└─────────────────────────────────────────────────────────────┘
```

### 6.2 固件构建流程（源码编译）

```
┌─────────────────────────────────────────────────────────────┐
│                     build_* 工作流                           │
├─────────────────────────────────────────────────────────────┤
│  repository_dispatch / workflow_dispatch                    │
│       │                                                     │
│       ▼                                                     │
│  1. 检出仓库 → 记录开始时间                                  │
│       │                                                     │
│       ▼                                                     │
│  2. 准备环境 → 安装依赖包                                    │
│       │                                                     │
│       ▼                                                     │
│  3. 克隆源码 → 到 /mnt/workdir                              │
│       │                                                     │
│       ▼                                                     │
│  4. DIY_P1_SH → 添加 feeds 和第三方包                       │
│       │                                                     │
│       ▼                                                     │
│  5. 更新安装 feeds                                          │
│       │                                                     │
│       ▼                                                     │
│  6. DIY_P2_SH → 修改系统配置 + 复制 files 目录              │
│       │                                                     │
│       ▼                                                     │
│  7. 生成更新日志 → GitHub API 获取                          │
│       │                                                     │
│       ▼                                                     │
│  8. 下载源码包 → make download                              │
│       │                                                     │
│       ▼                                                     │
│  9. 编译固件 → make V=s                                    │
│       │                                                     │
│       ▼                                                     │
│ 10. 整理输出 → 清理 packages 目录                           │
│       │                                                     │
│       ▼                                                     │
│ 11. 计算耗时 → 格式化输出                                   │
│       │                                                     │
│       ▼                                                     │
│ 12. 上传产物 → actions/upload-artifact                      │
│       │                                                     │
│       ▼                                                     │
│ 13. 创建 Release → softprops/action-gh-release              │
│       │                                                     │
│       ▼                                                     │
│ 14. 清理旧工作流 → 自定义脚本                              │
│       │                                                     │
│       ▼                                                     │
│ 15. 清理旧 Release → 自定义脚本                              │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 6.3 ImageBuilder 构建流程

```
┌─────────────────────────────────────────────────────────────┐
│                  imagebuilder_*.yml 工作流                  │
├─────────────────────────────────────────────────────────────┤
│  repository_dispatch / workflow_dispatch / schedule           │
│       │                                                     │
│       ▼                                                     │
│  1. 检查 version.buildinfo 变化                             │
│       │                                                     │
│       ▼                                                     │
│  2. 下载 ImageBuilder（多镜像源 fallback）                  │
│       │                                                     │
│       ▼                                                     │
│  3. 修改 ImageBuilder 配置                                 │
│       │   - 默认 IP: 192.168.50.1                          │
│       │   - 根分区大小: 512MB                                │
│       │   - 禁用不必要的文件系统                             │
│       │                                                     │
│       ▼                                                     │
│  4. 下载第三方 .ipk 软件包                                 │
│       │                                                     │
│       ▼                                                     │
│  5. 下载 PassWall 软件包                                    │
│       │                                                     │
│       ▼                                                     │
│  6. 打包固件 → make image PACKAGES="..."                      │
│       │                                                     │
│       ▼                                                     │
│  7. 整理输出                                               │
│       │                                                     │
│       ▼                                                     │
│  8. 上传产物 → actions/upload-artifact                      │
│       │                                                     │
│       ▼                                                     │
│  9. 创建 Release → softprops/action-gh-release              │
│       │                                                     │
│       ▼                                                     │
│ 10. 清理旧工作流和版本                                      │
│       │                                                     │
│       ▼                                                     │
│ 11. Pushplus 通知（可选）                                  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## 7. 环境变量说明

### 7.1 工作流环境变量

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `REPO_URL` | - | 源码仓库地址 |
| `REPO_BRANCH` | - | 源码分支 |
| `CONFIG_FILE` | - | 配置文件路径 |
| `DIY_P1_SH` | - | 第一阶段DIY脚本 |
| `DIY_P2_SH` | - | 第二阶段DIY脚本 |
| `UPLOAD_FIRMWARE` | `true` | 是否上传固件到 Artifacts |
| `UPLOAD_RELEASE` | `true` | 是否创建 GitHub Release |
| `TZ` | `Asia/Shanghai` | 时区设置 |
| `DEBIAN_FRONTEND` | `noninteractive` | Debian 前端模式 |
| `FORCE_JAVASCRIPT_ACTIONS_TO_NODE24` | `true` | 强制使用 Node.js 24 运行 JavaScript Actions |

### 7.2 运行时环境变量

| 变量 | 说明 |
|------|------|
| `TIME0` | 构建开始时间 |
| `TIME1` / `TIME2` | 构建结束时间 |
| `RELEASE_TAG` | Release 标签名（格式：`YYYY.MM.DD-HHMM`） |
| `FIRMWARE_DIR` / `FIRMWARE` | 固件输出目录路径 |
| `ELAPSED` | 编译耗时（格式：`HHh MMm SSs`） |
| `CHANGELOG_CONTENT` | 上游更新日志内容 |
| `GROUP_HASH` | 源码仓库最新 commit 哈希 |
| `BUILDINFO_CHANGELOG` | ImageBuilder version.buildinfo 变化日志 |

---

## 8. 故障排除

### 8.1 常见问题

#### 问题 1：构建超时

**原因**：GitHub Actions 免费版有时间限制（6小时），复杂配置可能超时

**解决方案**：
- 减少不必要的软件包
- 使用 `make -j1` 单线程编译（速度慢但更稳定）
- 考虑使用付费版或自托管 Runner

#### 问题 2：依赖下载失败

**原因**：网络问题或源站不可用

**解决方案**：
- 检查网络连通性
- ImageBuilder 工作流已配置多镜像源 fallback
- 手动下载依赖包到 `dl` 目录

#### 问题 3：Release 创建失败

**原因**：仓库 Actions 权限不足

**解决方案**：
- 在仓库 Settings → Actions → General 中启用 Read and write permissions
- 确认工作流内需要发布或清理的 job 已声明 `contents: write` / `actions: write`

#### 问题 4：Pushplus 推送失败

**原因**：未配置 `PUSHPLUS_TOKEN` Secret

**解决方案**：
- 在仓库 Secrets 中添加 `PUSHPLUS_TOKEN`
- 或不影响固件编译，可以忽略

### 8.2 日志查看

1. 进入仓库 Actions 页面
2. 选择失败的工作流运行
3. 点击失败的步骤查看详细日志
4. 根据错误信息定位问题

---

## 9. 扩展与定制

### 9.1 添加新的构建目标

1. 在 `.github/workflows/` 目录创建新的 YAML 文件
2. 配置环境变量（`REPO_URL`, `REPO_BRANCH`, `CONFIG_FILE` 等）
3. 添加对应的配置文件到 `config/` 目录
4. 创建对应的 DIY 脚本到 `scripts/` 目录
5. 在 `update-checker.yml` 或 `imagebuilder-update-checker.yml` 中添加更新检测（可选）

### 9.2 自定义编译选项

1. 运行 `make menuconfig` 配置选项
2. 保存配置到 `.config`
3. 将 `.config` 复制到 `config/` 目录并重命名

### 9.3 添加新的第三方软件包

在对应的 `*-diy-part1.sh` 中添加：

```bash
# 方式1：添加 feed
echo 'src-git myfeed https://github.com/user/repo.git' >> feeds.conf.default

# 方式2：直接克隆到 package 目录
git clone https://github.com/user/repo.git package/my-package
```

对于 ImageBuilder：

```bash
# 方式1：在 `PACKAGES` 参数中添加官方仓库中的软件包
make image PACKAGES="luci luci-app-my-package"

# 方式2：下载第三方 .ipk 到 packages/ 目录
wget -P ./packages https://example.com/luci-app-my-package.ipk
```

---

## 10. 参考资料

| 资源 | 链接 |
|------|------|
| 原项目 | [P3TERX/Actions-OpenWrt](https://github.com/P3TERX/Actions-OpenWrt) |
| LEDE 源码 | [coolsnowwolf/lede](https://github.com/coolsnowwolf/lede) |
| ImmortalWrt 源码 | [immortalwrt/immortalwrt](https://github.com/immortalwrt/immortalwrt) |
| OpenWrt 官方文档 | [openwrt.org/docs](https://openwrt.org/docs) |
| GitHub Actions 文档 | [docs.github.com/actions](https://docs.github.com/actions) |

---

**文档版本**: v2.0  
**生成日期**: 2026-06-06  
**项目地址**: [naoki66/Actions-OpenWrt](https://github.com/naoki66/Actions-OpenWrt)
