#!/usr/bin/env bash
#------------------------------------------------------------------------------
# LICENSE UPL 1.0
# Copyright (c) 1982-2026 Oracle and/or its affiliates. All rights reserved.
#
# 01_install_os_packages.sh
#   Installs base packages and the Oracle preinstall bundle for RAC 19c on OL7.
#------------------------------------------------------------------------------
# 中文说明：
# - 此脚本安装 Oracle RAC 预配所需的系统软件包与基础依赖。
# - 仅翻译面向使用者的提示信息，保留命令、变量、路径与配置键原样。

. /vagrant/scripts/_common.sh
# 共享工具函数负责日志格式、参数校验与磁盘解析。
require_root

log_section "正在安装基础软件包"
yum install -y deltarpm expect tree unzip zip openssl

log_section "正在安装 oracle-database-preinstall-19c"
yum install -y oracle-database-preinstall-19c

log_section "正在安装集群前置依赖"
yum install -y bc ksh libaio libaio-devel net-tools nfs-utils \
               policycoreutils-python sysstat smartmontools chrony \
               dnsmasq bind-utils rlwrap

log_section "正在禁用 firewalld"
systemctl stop    firewalld 2>/dev/null || true
systemctl disable firewalld 2>/dev/null || true
