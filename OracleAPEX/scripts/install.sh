#!/bin/bash
#
# LICENSE UPL 1.0
#
# Copyright © 1982-2019 Oracle and/or its affiliates. All rights reserved.
# Licensed under the Universal Permissive License v 1.0 as shown at http://oss.oracle.com/licenses/upl.
#
#    NAME
#      install.sh
#
#    DESCRIPTION
#      Execute Oracle Linux 7 update and configuration
#
#    NOTES
#       DO NOT ALTER OR REMOVE COPYRIGHT NOTICES OR THIS HEADER.
#
#    AUTHOR
#       Simon Coter
#
#    MODIFIED   (MM/DD/YY)
#    scoter     03/19/19 - Creation
#

# 中文说明：
# - 更新 Oracle Linux 并安装数据库前置依赖。
# - 为 XE、APEX 和 ORDS 后续部署准备基础环境。

echo 'INSTALLER：开始执行'

# get up to date
# 中文：先更新系统并执行 Oracle Linux 仓库配置。
yum update -y

# run OL Yum configuration
/usr/bin/ol_yum_configure.sh

echo 'INSTALLER：系统已更新'

# fix locale warning
yum reinstall -y glibc-common
echo LANG=en_US.utf-8 >> /etc/environment
echo LC_ALL=en_US.utf-8 >> /etc/environment

echo 'INSTALLER：Locale 已设置'

# Install Oracle Database prereq and openssl packages
# 中文：显式安装 preinstall 包，确保 /home/oracle 等目录正确创建。
# (preinstall is pulled automatically with 18c XE rpm, but it
#  doesn't create /home/oracle unless it's installed separately)
yum install -y oracle-database-preinstall-18c openssl

echo 'INSTALLER：Oracle preinstall 与 openssl 已安装完成'
