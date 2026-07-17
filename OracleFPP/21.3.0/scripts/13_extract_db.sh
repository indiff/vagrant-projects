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
# 用于校验并解压数据库软件介质。

. /vagrant/scripts/_common.sh
require_root
require_var DB_HOME
require_var DB_SOFTWARE

# 中文：先校验数据库介质，再解压到目标 ORACLE_HOME。
verify_installer_cksum "${DB_SOFTWARE}"

log_section "正在将 ${DB_SOFTWARE} 解压到 ${DB_HOME}"
mkdir -p "${DB_HOME}"
(
  cd "${DB_HOME}"
  unzip -oq "/vagrant/ORCL_software/${DB_SOFTWARE}"
)
chown -R grid:oinstall "${DB_HOME}"
log_success "已将 RDBMS 软件解压到 ${DB_HOME}"
