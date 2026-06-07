#!/bin/bash
#

# 修改默认IP
sed -i 's/192.168.1.1/192.168.50.1/g' package/base-files/files/bin/config_generate


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