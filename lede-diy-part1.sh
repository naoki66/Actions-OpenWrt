#!/bin/bash
#
#
#

# Uncomment a feed source
#sed -i 's/^#\(.*helloworld\)/\1/' feeds.conf.default

# Add a feed source 添加额外软件包
#echo 'src-git helloworld  https://github.com/fw876/helloworld.git;main' >>feeds.conf.default
#echo 'src-git ddnsgo https://github.com/sirpdboy/luci-app-ddns-go.git' >> feeds.conf.default
echo "src-git momo https://github.com/nikkinikki-org/OpenWrt-momo.git;main" >> "feeds.conf.default"
#echo 'src-git wechatpush  https://github.com/tty228/luci-app-wechatpush.git' >>feeds.conf.default
git clone  https://github.com/gdy666/luci-app-lucky.git package/lucky
