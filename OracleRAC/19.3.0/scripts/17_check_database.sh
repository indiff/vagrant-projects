#!/usr/bin/env bash
#------------------------------------------------------------------------------
# LICENSE UPL 1.0
# Copyright (c) 1982-2026 Oracle and/or its affiliates. All rights reserved.
#
# 17_check_database.sh
#   Report srvctl config/status for the freshly-created database.
#------------------------------------------------------------------------------
# 中文说明：
# - 此脚本输出新建数据库的 srvctl 配置与运行状态。
# - 仅翻译面向使用者的提示信息，保留命令、变量、路径与配置键原样。

. /vagrant/scripts/_common.sh
# 共享工具函数负责日志格式、参数校验与磁盘解析。
require_user oracle
require_var DB_HOME
require_var DB_NAME
require_var ORESTART

export ORACLE_HOME="${DB_HOME}"

log_section "正在执行 srvctl config database -d ${DB_NAME}"
if ! "${DB_HOME}/bin/srvctl" config database -d "${DB_NAME}"; then
  if [[ "${ORESTART}" == "true" ]]; then
    log_error "Oracle Restart 配置报告了错误"
  else
    log_error "Oracle RAC 配置报告了错误"
  fi
  exit 1
fi

log_section "正在执行 srvctl status database -d ${DB_NAME}"
"${DB_HOME}/bin/srvctl" status database -d "${DB_NAME}"

if [[ "${ORESTART}" == "true" ]]; then
  log_success "Vagrant 上的 Oracle Restart 已成功创建"
else
  log_success "Vagrant 上的 Oracle RAC 已成功创建"
fi
