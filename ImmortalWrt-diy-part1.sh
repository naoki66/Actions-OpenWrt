#!/bin/bash
#

# Uncomment a feed source
#sed -i 's/^#\(.*helloworld\)/\1/' feeds.conf.default

# Add a feed source
#echo 'src-git lucky https://github.com/gdy666/luci-app-lucky.git' >> feeds.conf.default
git clone  https://github.com/gdy666/luci-app-lucky.git package/lucky

