#!/bin/bash
#

# Uncomment a feed source
#sed -i 's/^#\(.*helloworld\)/\1/' feeds.conf.default

# Add a feed source
#添加lucky
git clone  https://github.com/gdy666/luci-app-lucky.git package/lucky
#添加rtp2httpd
echo "src-git rtp2httpd https://github.com/stackia/rtp2httpd.git;main" >> "feeds.conf.default"

#更新luci-app-mosdns
rm -rf feeds/packages/net/v2ray-geodata
rm -rf feeds/packages/net/mosdns
git clone https://github.com/sbwml/luci-app-mosdns -b v5 package/mosdns
git clone https://github.com/sbwml/v2ray-geodata package/v2ray-geodata
