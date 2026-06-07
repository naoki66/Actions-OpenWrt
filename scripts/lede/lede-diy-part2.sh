#!/bin/bash
#
#
#

# 修改默认IP
sed -i 's/192.168.1.1/192.168.50.1/g' package/base-files/files/bin/config_generate



# 日期
sed -i 's/os.date(/&"%Y-%m-%d %H:%M:%S"/' package/lean/autocore/files/x86/index.htm

# 把密码改成空
#sed -i 's@.*CYXluq4wUazHjmCDBCqXF*@#&@g' package/lean/default-settings/files/zzz-default-settings

#干掉跑分程序
#sed -i 's, <%=luci.sys.exec("cat /etc/bench.log") or " "%><,<,g'  package/lean/autocore/files/x86/index.htm
#rm -rf ./feeds/packages/utils/coremark

# 删除WAN6接口配置
#sed -i "/uci commit fstab/a\uci delete network.wan6" package/lean/default-settings/files/zzz-default-settings

# 删除ULA前缀配置
sed -i "/uci commit fstab/a\uci delete network.globals.ula_prefix" package/lean/default-settings/files/zzz-default-settings

# 设置LAN和全局网络参数
sed -i "/uci commit fstab/a\nuci set dhcp.lan.start='50'" package/lean/default-settings/files/zzz-default-settings

# 设置IPv6分配长度
sed -i "/uci commit fstab/a\nuci set network.lan.ip6assign='64'" package/lean/default-settings/files/zzz-default-settings

# 设置IPv6后缀为eui64自动生成
sed -i "/uci set network.lan.ip6assign='64'/a\nuci set network.lan.ip6hint='eui64'" package/lean/default-settings/files/zzz-default-settings

# 设置RA flags为none
sed -i "/uci set network.lan.ip6hint='eui64'/a\nuci set network.lan.ra_flags='none'\nuci commit network" package/lean/default-settings/files/zzz-default-settings


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