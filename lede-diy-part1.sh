#!/bin/bash
#
#
#

# Uncomment a feed source
#sed -i 's/^#\(.*helloworld\)/\1/' feeds.conf.default
#sed -i 's/^src-git luci .*openwrt-23\.05$/#&/' feeds.conf.default
#sed -i 's/^#src-git luci .*openwrt-24\.10$/src-git luci https:\/\/github\.com\/coolsnowwolf\/luci\.git;openwrt-24\.10/' feeds.conf.default


# Add a feed source 添加额外软件包
#echo 'src-git helloworld https://github.com/fw876/helloworld.git' >>feeds.conf.default
#echo 'src-git ddnsgo https://github.com/sirpdboy/luci-app-ddns-go.git' >> feeds.conf.default
#echo 'src-git wechatpush  https://github.com/tty228/luci-app-wechatpush.git' >>feeds.conf.default
git clone  https://github.com/gdy666/luci-app-lucky.git package/lucky
git clone  https://github.com/tty228/luci-app-wechatpush package/luci-app-wechatpush

