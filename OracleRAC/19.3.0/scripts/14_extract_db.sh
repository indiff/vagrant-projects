#!/usr/bin/env bash
#------------------------------------------------------------------------------
# LICENSE UPL 1.0
# Copyright (c) 1982-2026 Oracle and/or its affiliates. All rights reserved.
#
# 14_extract_db.sh
#   Verify and extract the RDBMS zip into DB_HOME. Runs as root so it can
#   chown the result to oracle:oinstall.
#------------------------------------------------------------------------------
# 中文说明：
# - 此脚本校验并解压数据库软件安装介质。
# - 仅翻译面向使用者的提示信息，保留命令、变量、路径与配置键原样。

. /vagrant/scripts/_common.sh
# 共享工具函数负责日志格式、参数校验与磁盘解析。
require_root
require_var DB_HOME
require_var DB_SOFTWARE

verify_installer_cksum "${DB_SOFTWARE}"

log_section "正在将 ${DB_SOFTWARE} 解压到 ${DB_HOME}"
mkdir -p "${DB_HOME}"
(
  cd "${DB_HOME}"
  unzip -oq "/vagrant/ORCL_software/${DB_SOFTWARE}"
)
chown -R oracle:oinstall "${DB_HOME}"
log_success "RDBMS 软件已解压到 ${DB_HOME}"
