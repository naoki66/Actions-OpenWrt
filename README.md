

🚀 仓库自动编译，感谢以下仓库的源主贡献。</br>
   ➦openwrt主源码来自https://github.com/immortalwrt/immortalwrt </br>
   ➦luci-app-lucky源码来自 https://github.com/gdy666/luci-app-lucky</br>
   ➦luci-app-mosdns源码来自 https://github.com/sbwml/luci-app-mosdns </br>
   ➦luci-app-wechatpush源码来自 https://github.com/tty228/luci-app-wechatpush </br>
   ➦passwall源码来自 https://github.com/xiaorouji/openwrt-passwall </br>

 </br>

首次编译：
```bash
export GOPROXY=https://goproxy.cn
git clone -b openwrt-24.10 --single-branch --filter=blob:none https://github.com/immortalwrt/immortalwrt
cd immortalwrt
./scripts/feeds update -a  && ./scripts/feeds install -a
make menuconfig
make download -j8
make V=s -j1
```

二次编译：
```bash
cd immortalwrt
export GOPROXY=https://goproxy.cn
git pull  && ./scripts/feeds update -a  && ./scripts/feeds install -a 
make defconfig && make download -j8
make V=s -j$(nproc)
```
重新配置：
```bash
rm -rf ./tmp && rm -rf .config
make menuconfig
make V=s -j$(nproc)
```

DNS protocol standard
```bash
General DNS (UDP): 119.29.29.29 & udp://119.29.29.29:53

General DNS (TCP): tcp://119.29.29.29 & tcp://119.29.29.29:53

DNS-over-TLS: tls://120.53.53.53 & tls://120.53.53.53:853

DNS-over-HTTPS: https://120.53.53.53/dns-query

DNS-over-HTTPS (HTTP/3): h3://dns.alidns.com/dns-query

DNS-over-QUIC: quic://dns.alidns.com & doq://dns.alidns.com
```


**English** | [中文](https://p3terx.com/archives/build-openwrt-with-github-actions.html)

# Actions-OpenWrt

[![LICENSE](https://img.shields.io/github/license/mashape/apistatus.svg?style=flat-square&label=LICENSE)](https://github.com/P3TERX/Actions-OpenWrt/blob/master/LICENSE)
![GitHub Stars](https://img.shields.io/github/stars/P3TERX/Actions-OpenWrt.svg?style=flat-square&label=Stars&logo=github)
![GitHub Forks](https://img.shields.io/github/forks/P3TERX/Actions-OpenWrt.svg?style=flat-square&label=Forks&logo=github)

A template for building OpenWrt with GitHub Actions

## Usage

- Click the [Use this template](https://github.com/P3TERX/Actions-OpenWrt/generate) button to create a new repository.
- Generate `.config` files using [Lean's OpenWrt](https://github.com/coolsnowwolf/lede) source code. ( You can change it through environment variables in the workflow file. )
- Push `.config` file to the GitHub repository.
- Select `Build OpenWrt` on the Actions page.
- Click the `Run workflow` button.
- When the build is complete, click the `Artifacts` button in the upper right corner of the Actions page to download the binaries.

## Tips

- It may take a long time to create a `.config` file and build the OpenWrt firmware. Thus, before create repository to build your own firmware, you may check out if others have already built it which meet your needs by simply [search `Actions-Openwrt` in GitHub](https://github.com/search?q=Actions-openwrt).
- Add some meta info of your built firmware (such as firmware architecture and installed packages) to your repository introduction, this will save others' time.

## Credits

- [Microsoft Azure](https://azure.microsoft.com)
- [GitHub Actions](https://github.com/features/actions)
- [OpenWrt](https://github.com/openwrt/openwrt)
- [Lean's OpenWrt](https://github.com/coolsnowwolf/lede)
- [tmate](https://github.com/tmate-io/tmate)
- [mxschmitt/action-tmate](https://github.com/mxschmitt/action-tmate)
- [csexton/debugger-action](https://github.com/csexton/debugger-action)
- [Cowtransfer](https://cowtransfer.com)
- [WeTransfer](https://wetransfer.com/)
- [Mikubill/transfer](https://github.com/Mikubill/transfer)
- [softprops/action-gh-release](https://github.com/softprops/action-gh-release)
- [ActionsRML/delete-workflow-runs](https://github.com/ActionsRML/delete-workflow-runs)
- [dev-drprasad/delete-older-releases](https://github.com/dev-drprasad/delete-older-releases)
- [peter-evans/repository-dispatch](https://github.com/peter-evans/repository-dispatch)

## License

[MIT](https://github.com/P3TERX/Actions-OpenWrt/blob/main/LICENSE) © [**P3TERX**](https://p3terx.com)
