#!/usr/bin/env bash
#------------------------------------------------------------------------------
# LICENSE UPL 1.0
# Copyright (c) 1982-2026 Oracle and/or its affiliates. All rights reserved.
#
# 01_install_os_packages.sh
#   Installs base packages and the Oracle preinstall bundle for 21c on OL8.
#------------------------------------------------------------------------------

# 中文说明：
# - 安装基础工具和与当前数据库版本匹配的 Oracle preinstall 包。
# - 关闭 firewalld，减少实验环境中主备互通的额外阻碍。

. /vagrant/scripts/_common.sh
require_root
# 中文：先安装基础工具，再补齐 Oracle 官方预安装依赖。

log_section "安装基础软件包"
dnf install -y dnf-utils parted openssl tree unzip zip

log_section "安装 oracle-database-preinstall-21c"
dnf install -y oracle-database-preinstall-21c

log_section "关闭 firewalld"
systemctl stop    firewalld 2>/dev/null || true
systemctl disable firewalld 2>/dev/null || true
