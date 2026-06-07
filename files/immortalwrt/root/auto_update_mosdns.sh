#!/bin/sh

# 定义核心路径
CIDR_FILE="/etc/mosdns/rule/cloudflare-cidr.txt"
TMP_V4_TXT="/tmp/cf_v4_local.txt"
TMP_V6_TXT="/tmp/cf_v6_local.txt"
RESULT_V4="/tmp/cf_res_v4.csv"
RESULT_V6="/tmp/cf_res_v6.csv"

# 1. 检查本地 MosDNS 规则文件是否存在
if [ ! -f "$CIDR_FILE" ]; then
    echo "【错误】未找到 MosDNS 的本地 IP 段文件: $CIDR_FILE"
    exit 1
fi

echo "正在智能发散与抽样双栈 IP 地址..."

# 【IPv4 优化】对 IPv4 引入步长抽样，每 12 个网段抽 1 个，保持 500 个左右的健康测试量
grep "\." "$CIDR_FILE" | awk 'NR%12==0 {print $0}' > "$TMP_V4_TXT"
if [ ! -s "$TMP_V4_TXT" ]; then grep "\." "$CIDR_FILE" > "$TMP_V4_TXT"; fi

# 【IPv6 深度发散】拒绝简单粗暴！将 7 个大大掩码网段，在内存中动态扩展出 100 多个不同子网的单播测试点
: > "$TMP_V6_TXT"
grep ":" "$CIDR_FILE" | awk -F'/' '{print $1}' | while read -r base_v6; do
    if [ -n "$base_v6" ]; then
        # 去除尾部可能存在的双冒号，统一格式
        prefix=$(echo "$base_v6" | sed 's/::$/:/')
        # 为每个大网段规律性衍生出 16 个散落各处的子网靶点，大大提升优选覆盖面
        for suffix in 1 10 50 100 a0 b5 f0 1a2 2b4 5c6 8e9 a10 d50 f99 ff0 ffff; do
            echo "${prefix}${suffix}::1" >> "$TMP_V6_TXT"
        done
    fi
done

# 2. 测速优选 IPv4
if [ -s "$TMP_V4_TXT" ]; then
    echo "正在测速优选最优 IPv4 节点（轻量抽样模式）..."
    cdnspeedtest -f "$TMP_V4_TXT" -n 150 -t 4 -tl 150 -tlr 0 -dd -p 4 -o "$RESULT_V4"
fi

# 3. 测速优选 IPv6 (测试深度发散后的 100+ 个核心节点)
if [ -s "$TMP_V6_TXT" ]; then
    echo "正在测速优选最优 IPv6 节点（多子网深度覆盖模式）..."
    cdnspeedtest -f "$TMP_V6_TXT" -n 150 -t 4 -tl 260 -tlr 0 -dd -p 4 -o "$RESULT_V6"
fi

# 4. 彻底清理旧的自选 IP 列表以及不规范的 cf_ips 垃圾字段
uci -q del mosdns.config.cloudflare_ip
uci -q del mosdns.config.cf_ips

# 5. 强制确保 Cloudflare 优选开关处于开启状态
uci set mosdns.config.cloudflare='1'

# 6. 精准提取各自前 4 个最优 IP 填入配置
HAS_IP=0

# 处理 IPv4：只拿延迟最低的 4 个
if [ -s "$RESULT_V4" ]; then
    for ip in $(awk -F, 'NR>1 {print $1}' "$RESULT_V4" | head -n 4); do
        if [ -n "$ip" ]; then
            uci add_list mosdns.config.cloudflare_ip="$ip"
            echo "→ 成功填入优选 IPv4: $ip"
            HAS_IP=1
        fi
    done
fi

# 处理 IPv6：从 100 多个发散节点中精准捕获真正最快的 4 个
if [ -s "$RESULT_V6" ]; then
    for ip in $(awk -F, 'NR>1 {print $1}' "$RESULT_V6" | head -n 4); do
        if [ -n "$ip" ]; then
            uci add_list mosdns.config.cloudflare_ip="$ip"
            echo "→ 成功填入优选 IPv6: $ip"
            HAS_IP=1
        fi
    done
fi

# 7. 提交配置并重启 MosDNS
if [ "$HAS_IP" -eq 1 ]; then
    uci commit mosdns
    /etc/init.d/mosdns restart
    echo "【大功告成】双栈（最高 4+4）最优均衡网络已成功应用，MosDNS 重启生效！"
else
    uci -q revert mosdns
    echo "【提示】未筛选出任何符合延迟要求的优质 IP，保持原界面配置不变。"
fi

# 8. 清理残留内存文件
rm -f "$TMP_V4_TXT" "$TMP_V6_TXT" "$RESULT_V4" "$RESULT_V6"
