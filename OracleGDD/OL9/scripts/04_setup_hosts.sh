#!/bin/bash
#│▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒
#
# Copyright (c) 2024 Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at
# https://oss.oracle.com/licenses/upl.
#
# Since: August, 2024
# Author: ruggero.citton@oracle.com
# Description: 04_setup_hosts.sh
#
# DO NOT ALTER OR REMOVE COPYRIGHT NOTICES OR THIS HEADER.
#
#│▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒│

# 中文说明：
# - 此脚本重建主机名解析配置，确保容器和数据库节点名称可解析。
# - 仅翻译面向使用者的提示信息，保留命令、变量、路径与配置键原样。

. /vagrant/config/setup.env
# 加载 Vagrant 生成的运行参数和统一日志样式。
echo "-----------------------------------------------------------------"
echo -e "${INFO}`date +%F' '%T`: 正在配置 /etc/hosts"
echo "-----------------------------------------------------------------"

# 先重写 hosts 文件，再补充实验节点记录。
cat > /etc/hosts <<EOF
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
EOF

cat >> /etc/hosts <<EOF
# Public host info
${NODE1_PUBLIC_IP}  ${NODE1_FQ_HOSTNAME}  ${NODE1_HOSTNAME}
EOF

echo "-----------------------------------------------------------------"
echo -e "${INFO}`date +%F' '%T`: 正在配置 /etc/resolv.conf"
echo "-----------------------------------------------------------------"
cat > /etc/resolv.conf <<EOF
search ${DOMAIN_NAME}
nameserver ${DNS_PUBLIC_IP}
EOF

#----------------------------------------------------------
# EndOfFile
#----------------------------------------------------------
