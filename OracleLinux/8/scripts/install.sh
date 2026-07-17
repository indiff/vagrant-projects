#!/bin/bash
#
# LICENSE UPL 1.0
#
# Copyright (c) 1982-2018 Oracle and/or its affiliates. All rights reserved.
#
# Since: January, 2018
# Author: gerald.venzl@oracle.com
# Description: Updates Oracle Linux to the latest version
#
# DO NOT ALTER OR REMOVE COPYRIGHT NOTICES OR THIS HEADER.
#

# 中文说明：
# - 此脚本更新 Oracle Linux 基础系统，并修复实验环境所需的 locale 或引导配置。
# - 仅翻译面向使用者的提示信息，保留命令、变量、路径与配置键原样。

echo '安装程序：已启动'

# 先更新基础系统，确保镜像处于最新补丁状态。
# get up to date
dnf upgrade -y

echo '安装程序：系统已更新'

# fix locale warning
echo LANG=en_US.utf-8 >> /etc/environment
echo LC_ALL=en_US.utf-8 >> /etc/environment

echo '安装程序：区域设置已完成'
