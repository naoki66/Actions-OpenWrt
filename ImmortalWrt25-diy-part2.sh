#!/bin/bash
#

# 修改默认IP
sed -i 's/192.168.1.1/192.168.50.1/g' package/base-files/files/bin/config_generate
