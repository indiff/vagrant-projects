#!/usr/bin/env bash
# shellcheck shell=bash
#------------------------------------------------------------------------------
# LICENSE UPL 1.0
# Copyright (c) 1982-2026 Oracle and/or its affiliates. All rights reserved.
#
# _common.sh
#   Shared helpers for all provisioning scripts in this project.
#   Must be sourced, not executed:  . /vagrant/scripts/_common.sh
#------------------------------------------------------------------------------

# 中文说明：
# - 该文件为所有 Oracle Data Guard 预配脚本提供公共日志与校验函数。
# - 统一开启严格模式，并按需载入 setup.sh 生成的运行时环境变量。


# Re-entrancy guard
if [[ -n "${__DG_COMMON_SH_LOADED:-}" ]]; then
  return 0
fi
__DG_COMMON_SH_LOADED=1

# Strict mode (applies to every script that sources this file)
set -o errexit
set -o errtrace
set -o nounset
set -o pipefail
IFS=$'\n\t'

# ANSI colour tags (overridable)
: "${INFO:=\033[0;34mINFO: \033[0m}"
: "${ERROR:=\033[1;31mERROR: \033[0m}"
: "${SUCCESS:=\033[1;32mSUCCESS: \033[0m}"

# Logging helpers
log_info()    { printf '%b%s: %s\n' "$INFO"    "$(date '+%F %T')" "$*"; }
log_error()   { printf '%b%s: %s\n' "$ERROR"   "$(date '+%F %T')" "$*" >&2; }
log_success() { printf '%b%s: %s\n' "$SUCCESS" "$(date '+%F %T')" "$*"; }

log_section() {
  printf '%s\n' '-----------------------------------------------------------------'
  log_info "$*"
  printf '%s\n' '-----------------------------------------------------------------'
}

# ERR trap — surfaces the exact failure site
# 中文：一旦命令失败，立即输出出错位置与原始命令。
__dg_on_err() {
  local exit_code=$?
  log_error "命令失败（exit=${exit_code}），位置 ${BASH_SOURCE[1]:-?}:${BASH_LINENO[0]:-?} —— '${BASH_COMMAND}'"
  exit "${exit_code}"
}
trap __dg_on_err ERR

# Source the runtime env file if present (not available during its own generation).
# 中文：优先从来宾机本地文件读取敏感变量，避免依赖共享目录权限。
# It lives on the guest filesystem so it does not depend on /vagrant mount
# semantics, which vary between providers.
: "${DG_SETUP_ENV_FILE:=/etc/opt/oracle-dg/setup.env}"
if [[ -r "${DG_SETUP_ENV_FILE}" ]]; then
  # setup.env is trusted: written by this project's setup.sh
  # shellcheck disable=SC1090
  . "${DG_SETUP_ENV_FILE}"
elif [[ -e "${DG_SETUP_ENV_FILE}" ]]; then
  log_error "用户 '$(id -un)' 无法读取 setup 环境文件 '${DG_SETUP_ENV_FILE}'"
  exit 1
fi

# Helpers used by several scripts
require_root() {
  if [[ "$(id -u)" -ne 0 ]]; then
    log_error "该脚本必须以 root 用户运行"
    exit 1
  fi
}

require_var() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    log_error "必需变量 '${name}' 未设置"
    exit 1
  fi
}
