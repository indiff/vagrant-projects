#!/usr/bin/env bash
#------------------------------------------------------------------------------
# LICENSE UPL 1.0
# Copyright (c) 1982-2026 Oracle and/or its affiliates. All rights reserved.
#
# 01_install_os_packages.sh
#   Installs base packages and the Oracle preinstall bundle that matches the
#   23.26.1 installer (the '26ai' preinstall package line on OL9).
#
#   If only the older oracle-database-preinstall-23ai package is available in
#   the configured repos we fall back to it, so this script runs cleanly on
#   environments that have not yet received the 26ai package.
#------------------------------------------------------------------------------

# 中文说明：
# - 安装基础工具和与当前数据库版本匹配的 Oracle preinstall 包。
# - 关闭 firewalld，减少实验环境中主备互通的额外阻碍。

. /vagrant/scripts/_common.sh
require_root
# 中文：先安装基础工具，再补齐 Oracle 官方预安装依赖。

log_section "安装基础软件包"
dnf install -y dnf-utils parted openssl tree unzip zip

log_section "安装 Oracle 预安装软件包"
if dnf -q list --available oracle-ai-database-preinstall-26ai >/dev/null 2>&1; then
  dnf install -y oracle-ai-database-preinstall-26ai
elif dnf -q list --available oracle-database-preinstall-23ai   >/dev/null 2>&1; then
  log_info "未找到 26ai 预安装包；回退到 oracle-database-preinstall-23ai"
  dnf install -y oracle-database-preinstall-23ai
else
  log_error "未找到兼容的 Oracle 预安装包（oracle-ai-database-preinstall-26ai 或 oracle-database-preinstall-23ai）"
  exit 1
fi

log_section "关闭 firewalld"
systemctl stop    firewalld 2>/dev/null || true
systemctl disable firewalld 2>/dev/null || true
