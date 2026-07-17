#!/bin/bash
#│▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒
#
# Copyright (c) 2024 Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at
# https://oss.oracle.com/licenses/upl.
#
# Since: August, 2024
# Author: ruggero.citton@oracle.com
# Description: 01_install_os_packages.sh
#
# DO NOT ALTER OR REMOVE COPYRIGHT NOTICES OR THIS HEADER.
#
#│▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒│
# 中文说明：
# - 此脚本安装 GDD 节点所需的软件包，并调整 locale、防火墙与 SELinux 设置。
# - 仅翻译面向使用者的提示信息，保留命令、变量、路径与配置键原样。

. /vagrant/config/setup.env
# 加载 Vagrant 生成的运行参数和统一日志样式。

## get up to date
#echo "-----------------------------------------------------------------"
#echo -e "${INFO}`date +%F' '%T`: INSTALLER: System update"
#echo "-----------------------------------------------------------------"
#dnf upgrade -y


# fix locale warning
echo "-----------------------------------------------------------------"
echo -e "${INFO}`date +%F' '%T`: 区域设置已完成"
echo "-----------------------------------------------------------------"
dnf reinstall -y glibc-common
echo 'LANG=en_US.utf-8' >> /etc/environment
echo 'LC_ALL=en_US.utf-8' >> /etc/environment


# Install Oracle Database preinstall and openssl packages
echo "-----------------------------------------------------------------"
echo -e "${INFO}`date +%F' '%T`: Oracle 预安装包、openssl、parted 和 expect 已安装"
echo "-----------------------------------------------------------------"
dnf install -y oracle-database-preinstall-23ai openssl parted expect


# Install Podman
echo "-----------------------------------------------------------------"
echo -e "${INFO}`date +%F' '%T`: 正在配置 Podman"
echo "-----------------------------------------------------------------"
dnf config-manager --enable ol9_appstream
dnf install -y podman
dnf install -y selinux-policy-devel

dnf install -y oracle-epel-release-el9
dnf install -y podman-compose

echo "-----------------------------------------------------------------"
echo -e "${INFO}`date +%F' '%T`: 正在禁用防火墙"
echo "-----------------------------------------------------------------"
systemctl stop firewalld
systemctl disable firewalld

echo "-----------------------------------------------------------------"
echo -e "${INFO}`date +%F' '%T`: 正在将 SELinux 设置为 permissive"
echo "-----------------------------------------------------------------"
sed -i -e "s|SELINUX=enforcing|SELINUX=permissive|g" /etc/selinux/config
setenforce permissive
#----------------------------------------------------------
# EndOfFile
#----------------------------------------------------------

