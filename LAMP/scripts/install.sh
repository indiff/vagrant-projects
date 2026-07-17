#!/bin/bash
#
# LICENSE UPL 1.0
#
# Copyright (c) 2018, 2020 Oracle and/or its affiliates.
#
# Since: January, 2018
# Author: gerald.venzl@oracle.com
# Description: Updates Oracle Linux to the latest version
#
# DO NOT ALTER OR REMOVE COPYRIGHT NOTICES OR THIS HEADER.
#

# 中文说明：
# - 执行基础系统更新并修复 locale 设置。
# - 为后续 LAMP 组件安装准备干净的 Oracle Linux 环境。

echo 'INSTALLER：开始执行'

# get up to date
# 中文：先升级基础系统包，减少后续安装中的依赖问题。
yum upgrade -y

echo 'INSTALLER：系统已更新'

# fix locale warning
# 中文：补充环境变量，避免 Perl 和 shell 输出 locale 警告。
echo LANG=en_US.utf-8 >> /etc/environment
echo LC_ALL=en_US.utf-8 >> /etc/environment

echo 'INSTALLER：Locale 已设置'
