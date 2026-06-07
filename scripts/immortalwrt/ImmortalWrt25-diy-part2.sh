#!/bin/bash
#
#  修改默认主机名为XXX(可根据喜好自行修改)
# sed -i "s/hostname='ImmortalWrt'/hostname='OPLT'/g" package/base-files/files/bin/config_generate
# 修改默认IP
sed -i 's/192.168.1.1/192.168.50.1/g' package/base-files/files/bin/config_generate
# 3. 修改默认时区为中国标准时间 (CST-8, Asia/Shanghai)
sed -i "s/timezone='GMT0'/timezone='CST-8'/g" package/base-files/files/bin/config_generate
sed -i "s/zonename='UTC'/zonename='Asia\/Shanghai'/g" package/base-files/files/bin/config_generate
# 5. 调整默认 IPv6 分配长度（将原本的 60 变更为通用的 64）
sed -i "s/ip6assign='60'/ip6assign='64'/g" package/base-files/files/bin/config_generate

# 6. 强行删除默认下发的 ULA 内网 IPv6 前缀 (避免污染公网 v6 优先级)
#sed -i "s/set network.globals.ula_prefix='auto'/delete network.globals.ula_prefix/g" package/base-files/files/bin/config_generate

# 强行开启“作为 NTP 服务器提供服务” (enable_server='1')
sed -i "s/set system.ntp.enable_server='0'/set system.ntp.enable_server='1'/g" package/base-files/files/bin/config_generate


# =================================================================
# 自动为固件 files 目录下的所有脚本和初始化配置批量赋予执行权限
# =================================================================
echo "★ 正在通过 diy-part2.sh 批量更新自定义 files 的脚本执行权限..."

# 1. 批量赋权 files 目录下所有的 .sh 脚本（包括 /root/auto_update_mosdns.sh）
if [ -d "files" ]; then
    find files/ -type f -name "*.sh" -exec chmod +x {} +
    
    # 2. 顺便给系统首次开机初始化目录（uci-defaults）下的所有脚本批量赋权
    if [ -d "files/etc/uci-defaults" ]; then
        find files/etc/uci-defaults/ -type f -exec chmod +x {} +
    fi
fi
# =================================================================

