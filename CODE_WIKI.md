# Actions-OpenWrt 项目文档

## 1. 项目概述

`Actions-OpenWrt` 是一个基于 **GitHub Actions** 的 OpenWrt 固件自动化编译项目。该项目实现了从源码获取、自定义配置到固件编译和发布的全流程自动化。

### 1.1 项目定位

| 属性 | 说明 |
|------|------|
| **项目类型** | CI/CD 自动化流水线 |
| **目标平台** | OpenWrt 路由器固件 |
| **核心能力** | 自动化检测上游更新、编译固件、发布版本 |
| **支持源码** | ImmortalWrt、LEDE (Lean's OpenWrt) |

### 1.2 主要特性

- 🔄 **自动更新检测**：定时检查上游源码仓库更新，自动触发编译
- 🛠️ **自定义配置**：支持通过 DIY 脚本自定义 feeds 和系统配置
- 📦 **多版本支持**：同时支持 ImmortalWrt 和 LEDE 两大主流 OpenWrt 分支
- 🚀 **自动化发布**：编译完成后自动创建 GitHub Release
- 🧹 **自动清理**：定期清理旧工作流记录和旧版本

---

## 2. 项目架构

### 2.1 整体架构图

```
┌─────────────────────────────────────────────────────────────────┐
│                    GitHub Actions 工作流                        │
├─────────────────────────────────────────────────────────────────┤
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐     │
│  │ update-checker│───▶│ build_ImmortalWrt│───▶│ build_lede   │     │
│  │ (定时触发)    │    │ (24.10/25.12)│    │ (X64/R68S)   │     │
│  └──────────────┘    └──────────────┘    └──────────────┘     │
│         │                  │                  │                │
│         ▼                  ▼                  ▼                │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐     │
│  │ 检测上游更新  │    │ 克隆源码     │    │ 应用DIY脚本  │     │
│  │ 计算哈希对比  │    │ 更新feeds    │    │ 编译固件     │     │
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
│       ├── imagebuilder_*.yml          # ImageBuilder 构建配置
│       ├── update-checker.yml          # 更新检测工作流
│       └── update-tag-checker.yml      # 标签更新检测
├── Lede_Files/
│   └── etc/config/google_fu_mode       # LEDE 自定义配置文件
├── ImmortalWrt-diy-part1.sh            # ImmortalWrt 第一阶段DIY
├── ImmortalWrt-diy-part2.sh            # ImmortalWrt 第二阶段DIY
├── ImmortalWrt25-diy-part1.sh          # ImmortalWrt 25.x DIY
├── ImmortalWrt25-diy-part2.sh
├── lede-diy-part1.sh                   # LEDE 第一阶段DIY
├── lede-diy-part2.sh                   # LEDE 第二阶段DIY
├── lede-iptv.sh                        # LEDE IPTV 配置脚本
├── depends-ubuntu                      # Ubuntu 依赖说明
├── *.config                            # OpenWrt 配置文件
└── README.md                           # 项目说明
```

### 2.3 模块职责划分

| 模块 | 职责 | 关键文件 |
|------|------|----------|
| **更新检测模块** | 定时检查上游源码更新，触发编译 | `update-checker.yml` |
| **构建模块** | 克隆源码、编译固件 | `build_*.yml` |
| **自定义模块** | 添加 feeds、修改系统配置 | `*-diy-part1.sh`, `*-diy-part2.sh` |
| **发布模块** | 创建 Release、上传固件 | GitHub Actions 内置步骤 |
| **清理模块** | 清理旧工作流和版本 | 工作流内置步骤 |

---

## 3. 核心文件详解

### 3.1 工作流配置文件

#### 3.1.1 build_lede-X64.yml

**功能定位**：构建 LEDE X64 架构固件的核心工作流

**触发机制**：
- `repository_dispatch`: 接收 `lede-group-update` 事件（由 update-checker 触发）
- `workflow_dispatch`: 手动触发

**关键环境变量**：

| 变量 | 值 | 说明 |
|------|----|------|
| `REPO_URL` | `https://github.com/coolsnowwolf/lede` | 源码仓库地址 |
| `REPO_BRANCH` | `master` | 源码分支 |
| `CONFIG_FILE` | `lede-x64.config` | 配置文件路径 |
| `DIY_P1_SH` | `lede-diy-part1.sh` | 第一阶段DIY脚本 |
| `DIY_P2_SH` | `lede-diy-part2.sh` | 第二阶段DIY脚本 |
| `UPLOAD_FIRMWARE` | `true` | 是否上传固件产物 |
| `UPLOAD_RELEASE` | `true` | 是否创建 Release |

**工作流阶段**：

| 阶段 | 步骤 | 说明 |
|------|------|------|
| 1️⃣ 检出仓库 | `actions/checkout@v4` | 获取项目文件 |
| 2️⃣ 准备环境 | 安装依赖包 | 安装编译所需的所有依赖 |
| 3️⃣ 克隆源码 | `git clone` | 克隆 LEDE 源码到 `/mnt/workdir` |
| 4️⃣ 自定义 feeds | 执行 `DIY_P1_SH` | 添加第三方 feeds |
| 5️⃣ 更新安装 feeds | `./scripts/feeds update/install` | 更新并安装所有 feeds |
| 6️⃣ 自定义配置 | 执行 `DIY_P2_SH` | 修改系统默认配置 |
| 7️⃣ 生成更新日志 | GitHub API | 获取上游最近7天更新 |
| 8️⃣ 下载源码包 | `make download` | 预下载所有依赖包 |
| 9️⃣ 编译固件 | `make V=s` | 编译 OpenWrt 固件 |
| 🔟 整理输出 | 清理 packages | 只保留固件文件 |
| 1️⃣1️⃣ 计算耗时 | 时间戳对比 | 统计编译总耗时 |
| 1️⃣2️⃣ 上传产物 | `actions/upload-artifact` | 上传到 GitHub Artifacts |
| 1️⃣3️⃣ 创建 Release | `softprops/action-gh-release` | 发布到 GitHub Release |
| 1️⃣4️⃣ 清理旧记录 | `delete-workflow-runs` | 删除3天前的工作流记录 |
| 1️⃣5️⃣ 清理旧版本 | `delete-older-releases` | 保留最近12个版本 |

#### 3.1.2 build_ImmortalWrt_24.10.yml

**功能定位**：构建 ImmortalWrt 24.10 X64 架构固件

**与 LEDE 构建的主要差异**：

| 差异点 | LEDE | ImmortalWrt |
|--------|------|-------------|
| 源码仓库 | `coolsnowwolf/lede` | `immortalwrt/immortalwrt` |
| 分支 | `master` | `openwrt-24.10` |
| DIY脚本 | `lede-diy-*.sh` | `ImmortalWrt-diy-*.sh` |
| 配置文件 | `lede-x64.config` | `ImmortalWrt-24.10-x64.config` |
| 依赖包 | 标准 LEDE 依赖 | 额外需要 `libyaml-dev`, `zstd` 等 |

#### 3.1.3 update-checker.yml

**功能定位**：定时检测上游源码更新，触发自动编译

**触发机制**：
- `workflow_dispatch`: 手动触发
- `schedule`: 每天凌晨 1:40（中国时间）

**核心逻辑**：

1. **分组检测**：将源码分为两组
   - `immortalwrt-group`: immortalwrt, packages, luci
   - `lede-group`: lede, luci, packages

2. **哈希计算**：
   - 获取每个仓库最新 commit 哈希
   - 将组内所有仓库哈希拼接后计算 SHA256
   - 得到组合哈希 `GROUP_HASH`

3. **更新判断**：
   - 从缓存读取上次的组合哈希
   - 对比新旧哈希，若不同则触发构建

4. **触发构建**：
   - 通过 `repository_dispatch` 发送事件
   - 事件类型：`immortalwrt-group-update` 或 `lede-group-update`

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

**设计意图**：定制化系统默认配置，减少用户首次配置工作量

#### 3.2.3 ImmortalWrt-diy-part1.sh

**功能定位**：ImmortalWrt 的第一阶段自定义脚本

**核心操作**：

```bash
# 克隆 luci-app-lucky
git clone --depth 1 https://github.com/gdy666/luci-app-lucky.git package/lucky

# 添加 nikki feed（包含额外插件）
echo "src-git nikki https://github.com/nikkinikki-org/OpenWrt-nikki.git;main" >> "feeds.conf.default"

# 添加 rtp2httpd feed（RTSP 转 HTTP 工具）
echo "src-git rtp2httpd https://github.com/stackia/rtp2httpd.git;main" >> "feeds.conf.default"
```

**与 LEDE 版本差异**：使用 `--depth 1` 进行浅克隆，加快速度

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

#### 3.3.2 配置文件格式

配置文件采用 OpenWrt 标准 `.config` 格式，包含编译选项、软件包选择等：

```bash
CONFIG_TARGET_x86=y
CONFIG_TARGET_x86_64=y
CONFIG_TARGET_x86_64_Generic=y
CONFIG_PACKAGE_luci-app-opkg=y
CONFIG_PACKAGE_luci-app-firewall=y
CONFIG_PACKAGE_luci-app-ddns=y
# 更多配置...
```

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

### 4.3 GitHub Actions 依赖

| Action | 版本 | 用途 |
|--------|------|------|
| `actions/checkout` | v4 | 检出仓库代码 |
| `actions/upload-artifact` | v4 | 上传构建产物 |
| `softprops/action-gh-release` | v2 | 创建 GitHub Release |
| `peter-evans/repository-dispatch` | v2 | 触发仓库事件 |
| `actions/cache` | v4 | 缓存 commit 哈希 |
| `Mattraks/delete-workflow-runs` | v2 | 删除旧工作流记录 |
| `dev-drprasad/delete-older-releases` | v0.3.4 | 删除旧 Release |

### 4.4 系统依赖（Ubuntu 22.04）

编译 OpenWrt 需要安装以下依赖包：

```bash
# 基础编译工具
build-essential autoconf automake bison flex gcc-multilib g++-multilib

# 工具链
binutils gettext libtool make patch pkgconf

# 库依赖
libc6-dev-i386 libelf-dev libglib2.0-dev libgmp3-dev libmpc-dev libmpfr-dev
libncurses5-dev libncursesw5-dev libreadline-dev libssl-dev

# 辅助工具
git curl wget rsync subversion unzip zip p7zip p7zip-full
scons ninja-build cmake clang llvm
squashfs-tools genisoimage device-tree-compiler
python3 python3-pyelftools python3-setuptools
```

---

## 5. 项目运行方式

### 5.1 前提条件

1. **GitHub 账号**：需要拥有 GitHub 账号
2. **仓库模板**：使用此仓库模板创建自己的仓库
3. **Access Token**：创建具有 `public_repo` 权限的 Personal Access Token
4. **Secrets 配置**：
   - `ACTIONS_TRIGGER_PAT`: 用于触发工作流和创建 Release
   - `ServerChan`（可选）: 用于微信推送通知

### 5.2 配置步骤

1. **创建 Token**：
   - 进入 GitHub Settings → Developer settings → Personal access tokens
   - 生成新 token，勾选 `public_repo` 权限
   - 复制 token 值

2. **配置 Secrets**：
   - 进入仓库 Settings → Secrets and variables → Actions
   - 添加 `ACTIONS_TRIGGER_PAT`，值为上述 token
   - （可选）添加 `ServerChan`，值为 ServerChan SCKEY

3. **自定义配置**：
   - 修改 `lede-x64.config` 或对应配置文件
   - 修改 `lede-diy-part1.sh` 添加需要的 feeds
   - 修改 `lede-diy-part2.sh` 调整系统配置

### 5.3 触发方式

#### 方式一：自动触发（上游更新）

`update-checker.yml` 每天凌晨 1:40 自动运行：
- 检测上游仓库是否有新提交
- 若有更新，自动触发对应构建工作流

#### 方式二：手动触发

1. 进入仓库 Actions 页面
2. 选择目标工作流（如 "构建LEDE-X64固件"）
3. 点击 "Run workflow"
4. 选择分支后点击 "Run workflow"

#### 方式三：定时触发（可选）

取消工作流配置中的注释：

```yaml
# schedule:
#   - cron: '40 16 */7 * *'  # 每 7 天北京时间 00:40
```

### 5.4 本地编译（调试用）

**首次编译**：

```bash
export GOPROXY=https://goproxy.cn
git clone -b master --single-branch --filter=blob:none https://github.com/coolsnowwolf/lede
cd lede
./scripts/feeds update -a && ./scripts/feeds install -a
make menuconfig
make download -j8
make V=s -j$(nproc)
```

**二次编译**：

```bash
cd lede
export GOPROXY=https://goproxy.cn
git pull && ./scripts/feeds update -a && ./scripts/feeds install -a
make defconfig && make download -j8
make V=s -j$(nproc)
```

**重新配置**：

```bash
rm -rf ./tmp && rm -rf .config
make menuconfig
make V=s -j$(nproc)
```

---

## 6. 工作流执行流程

### 6.1 更新检测流程

```
┌─────────────────────────────────────────────────────────────┐
│                    update-checker 工作流                    │
├─────────────────────────────────────────────────────────────┤
│  定时触发 (每天 1:40)                                       │
│       │                                                     │
│       ▼                                                     │
│  ┌──────────────┐                                           │
│  │ 恢复缓存     │ ← 获取上次保存的组合哈希                    │
│  └──────┬───────┘                                           │
│         │                                                   │
│         ▼                                                   │
│  ┌──────────────┐                                           │
│  │ 获取最新哈希  │ ← 遍历组内所有仓库，获取最新 commit        │
│  └──────┬───────┘                                           │
│         │                                                   │
│         ▼                                                   │
│  ┌──────────────┐                                           │
│  │ 对比哈希     │                                           │
│  └──────┬───────┘                                           │
│         │                                                   │
│    ┌────┴────┐                                              │
│    │         │                                              │
│   相同      不同                                            │
│    │         │                                              │
│    ▼         ▼                                              │
│  结束    ┌──────────────┐                                   │
│          │ 触发构建     │ ← repository_dispatch             │
│          └──────┬───────┘                                   │
│                 │                                           │
│                 ▼                                           │
│          ┌──────────────┐                                   │
│          │ 保存新哈希   │ ← 更新缓存                         │
│          └──────────────┘                                   │
└─────────────────────────────────────────────────────────────┘
```

### 6.2 固件构建流程

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
│  6. DIY_P2_SH → 修改系统配置                                │
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
│ 14. 清理旧工作流 → delete-workflow-runs                     │
│       │                                                     │
│       ▼                                                     │
│ 15. 清理旧 Release → delete-older-releases                  │
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

### 7.2 运行时环境变量

| 变量 | 说明 |
|------|------|
| `TIME0` | 构建开始时间 |
| `TIME1` | 构建结束时间 |
| `RELEASE_TAG` | Release 标签名（格式：`YYYY.MM.DD-HHMM`） |
| `FIRMWARE_DIR` | 固件输出目录路径 |
| `ELAPSED` | 编译耗时（格式：`HHh MMm SSs`） |
| `CHANGELOG_CONTENT` | 上游更新日志内容 |

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
- 设置 `GOPROXY=https://goproxy.cn`
- 检查网络连通性
- 手动下载依赖包到 `dl` 目录

#### 问题 3：微信推送失败

**原因**：未配置 `ServerChan` Secret

**解决方案**：
- 在仓库 Secrets 中添加 `ServerChan`
- 或注释掉工作流中的微信推送步骤

#### 问题 4：权限不足

**原因**：Token 权限不够或未配置

**解决方案**：
- 确保 `ACTIONS_TRIGGER_PAT` 具有 `public_repo` 权限
- 检查 Token 是否正确配置

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
3. 添加对应的配置文件（如 `new-target.config`）
4. 创建对应的 DIY 脚本（如 `new-target-diy-part1.sh`）

### 9.2 自定义编译选项

1. 运行 `make menuconfig` 配置选项
2. 保存配置到 `.config`
3. 将 `.config` 复制到项目根目录并重命名

### 9.3 添加新的第三方软件包

在对应的 `*-diy-part1.sh` 中添加：

```bash
# 方式1：添加 feed
echo 'src-git myfeed https://github.com/user/repo.git' >> feeds.conf.default

# 方式2：直接克隆到 package 目录
git clone https://github.com/user/repo.git package/my-package
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

**文档版本**: v1.0  
**生成日期**: 2026-05-22  
**项目地址**: [naoki66/Actions-OpenWrt](https://github.com/naoki66/Actions-OpenWrt)