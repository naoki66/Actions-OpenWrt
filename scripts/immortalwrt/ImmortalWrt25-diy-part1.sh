#!/bin/bash

set -e

echo "=== 开始执行 DIY_P1_SH ==="

echo "添加 lucky..."
git clone --depth 1 https://github.com/gdy666/luci-app-lucky.git package/lucky || {
  echo "警告: 克隆 lucky 失败，尝试使用浅克隆..."
  git clone --depth 1 --single-branch https://github.com/gdy666/luci-app-lucky.git package/lucky || {
    echo "错误: 克隆 lucky 失败"
    exit 1
  }
}

echo "添加 rtp2httpd feed..."
echo "src-git rtp2httpd https://github.com/stackia/rtp2httpd.git;main" >> "feeds.conf.default"

echo "更新 luci-app-mosdns..."
rm -rf feeds/packages/net/v2ray-geodata
rm -rf feeds/packages/net/mosdns
rm -rf package/mosdns
rm -rf package/v2ray-geodata

git clone --depth 1 https://github.com/sbwml/luci-app-mosdns -b v5 package/mosdns || {
  echo "警告: 克隆 luci-app-mosdns 失败"
  exit 1
}
git clone --depth 1 https://github.com/sbwml/v2ray-geodata package/v2ray-geodata || {
  echo "警告: 克隆 v2ray-geodata 失败"
  exit 1
}

echo "=== DIY_P1_SH 执行完成 ==="
