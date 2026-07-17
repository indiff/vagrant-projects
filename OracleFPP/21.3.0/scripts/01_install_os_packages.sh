#!/usr/bin/env bash
#------------------------------------------------------------------------------
# LICENSE UPL 1.0
# Copyright (c) 1982-2026 Oracle and/or its affiliates. All rights reserved.
#
# 01_install_os_packages.sh
#   Installs base packages and the Oracle preinstall bundle for RAC 21c on OL8.
#------------------------------------------------------------------------------
# 中文说明：
# 用于安装 FPP/RAC 所需的基础软件和 Oracle 预安装包。

. /vagrant/scripts/_common.sh
require_root

log_section "正在安装基础软件包"
yum install -y expect tree unzip zip openssl dnsmasq parted

log_section "正在安装 oracle-database-preinstall-21c"
yum install -y oracle-database-preinstall-21c

log_section "正在禁用 firewalld"
systemctl stop    firewalld 2>/dev/null || true
systemctl disable firewalld 2>/dev/null || true
