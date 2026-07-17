#!/usr/bin/env bash
# shellcheck shell=bash
#------------------------------------------------------------------------------
# LICENSE UPL 1.0
# Copyright (c) 1982-2026 Oracle and/or its affiliates. All rights reserved.
#
# _common.sh
#   Shared helpers for all RAC provisioning scripts.
#   Must be sourced, not executed:  . /vagrant/scripts/_common.sh
#------------------------------------------------------------------------------

# Re-entrancy guard
# 中文说明：
# 提供所有 FPP 预配脚本共用的日志、校验和设备辅助函数。

if [[ -n "${__RAC_COMMON_SH_LOADED:-}" ]]; then
  return 0
fi
__RAC_COMMON_SH_LOADED=1

# Strict mode (applies to every script that sources this file)
set -o errexit
set -o errtrace
set -o nounset
set -o pipefail
IFS=$'\n\t'

# ANSI colour tags (overridable)
: "${INFO:=\033[0;34m提示：\033[0m}"
: "${ERROR:=\033[1;31m错误：\033[0m}"
: "${SUCCESS:=\033[1;32m成功：\033[0m}"

log_info()    { printf '%b%s: %s\n' "$INFO"    "$(date '+%F %T')" "$*"; }
log_error()   { printf '%b%s: %s\n' "$ERROR"   "$(date '+%F %T')" "$*" >&2; }
log_success() { printf '%b%s: %s\n' "$SUCCESS" "$(date '+%F %T')" "$*"; }

log_section() {
  printf '%s\n' '-----------------------------------------------------------------'
  log_info "$*"
  printf '%s\n' '-----------------------------------------------------------------'
}

# ERR trap — surfaces the exact failure site
__rac_on_err() {
  local exit_code=$?
  log_error "命令失败（exit=${exit_code}），位置 ${BASH_SOURCE[1]:-?}:${BASH_LINENO[0]:-?} —— '${BASH_COMMAND}'"
  exit "${exit_code}"
}
trap __rac_on_err ERR

# Runtime env file. Lives on the guest filesystem (not /vagrant) so the
# oracle/grid users can source it without the provider-specific
# synced-folder permission quirks.
# 中文：统一加载运行时环境，确保后续脚本使用相同变量集。
: "${RAC_SETUP_ENV_FILE:=/etc/opt/oracle-rac/setup.env}"
if [[ -r "${RAC_SETUP_ENV_FILE}" ]]; then
  # setup.env is trusted: written by this project's setup.sh
  # shellcheck disable=SC1090
  . "${RAC_SETUP_ENV_FILE}"
elif [[ -e "${RAC_SETUP_ENV_FILE}" ]]; then
  log_error "用户 '$(id -un)' 无法读取安装环境文件 '${RAC_SETUP_ENV_FILE}'"
  exit 1
fi

require_root() {
  if [[ "$(id -u)" -ne 0 ]]; then
    log_error "该脚本必须以 root 身份运行"
    exit 1
  fi
}

require_user() {
  local want="$1"
  if [[ "$(id -un)" != "${want}" ]]; then
    log_error "该脚本必须以用户 '${want}' 运行（当前用户：'$(id -un)'）"
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

device_prefix_for_provider() {
  local provider="$1"
  case "${provider}" in
    libvirt)    printf '%s\n' 'vd' ;;
    virtualbox) printf '%s\n' 'sd' ;;
    *)          log_error "不支持的 provider：'${provider}'"; return 1 ;;
  esac
}

disk_suffix_from_index() {
  local idx="$1"
  if ! [[ "${idx}" =~ ^[0-9]+$ ]]; then
    log_error "磁盘索引必须是非负整数（实际值：'${idx}'）"
    return 1
  fi

  local value=$((idx + 1))
  local suffix='' rem octal letter
  while (( value > 0 )); do
    rem=$(((value - 1) % 26))
    printf -v octal '%03o' $((97 + rem))
    printf -v letter '%b' "\\${octal}"
    suffix="${letter}${suffix}"
    value=$(((value - 1) / 26))
  done
  printf '%s\n' "${suffix}"
}

wait_for_block_device() {
  local path="$1"
  local attempts="${2:-30}"
  local delay="${3:-1}"
  local attempt

  for ((attempt = 1; attempt <= attempts; attempt++)); do
    if [[ -b "${path}" ]]; then
      return 0
    fi
    udevadm settle || true
    sleep "${delay}"
  done

  log_error "等待块设备 ${path} 超时"
  return 1
}

chown_block_device() {
  local path="$1"
  local owner_group="$2"
  local attempts="${3:-30}"
  local delay="${4:-1}"
  local attempt

  for ((attempt = 1; attempt <= attempts; attempt++)); do
    if [[ -b "${path}" ]] && chown "${owner_group}" "${path}" 2>/dev/null; then
      return 0
    fi
    udevadm settle || true
    sleep "${delay}"
  done

  if [[ ! -b "${path}" ]]; then
    log_error "在 chown 前等待块设备 ${path} 超时"
    return 1
  fi

  chown "${owner_group}" "${path}"
}

# Verify an installer zip against the project's db_installer.cksum manifest.
# Args: $1 = zip basename (e.g. LINUX.X64_193000_db_home.zip)
# 中文：校验安装介质，尽早发现版本或文件损坏问题。
verify_installer_cksum() {
  local installer="$1"
  local zip_path="/vagrant/ORCL_software/${installer}"
  local manifest="/vagrant/db_installer.cksum"

  [[ -f "${zip_path}" ]] || { log_error "未在以下路径找到安装 zip：${zip_path}"; return 1; }
  [[ -f "${manifest}" ]] || { log_error "未在以下路径找到校验清单：${manifest}"; return 1; }

  local expected_crc='' expected_size='' expected_name=''
  local line entry_crc entry_size entry_name
  while IFS= read -r line; do
    [[ -z "${line}" || "${line}" == \#* ]] && continue
    IFS=' ' read -r entry_crc entry_size entry_name <<< "${line}"
    if [[ "${entry_name##*/}" == "${installer}" ]]; then
      expected_crc="${entry_crc}"
      expected_size="${entry_size}"
      expected_name="${entry_name}"
      break
    fi
  done < "${manifest}"

  if [[ -z "${expected_crc}" || -z "${expected_size}" ]]; then
    log_error "在 ${manifest} 中未找到 ${installer} 的校验记录"
    return 1
  fi
  if ! [[ "${expected_crc}" =~ ^[0-9]+$ && "${expected_size}" =~ ^[0-9]+$ ]]; then
    log_error "${manifest} 中 ${installer} 的校验记录无效"
    return 1
  fi

  log_section "正在根据 ${manifest} 校验 ${installer}"
  local actual_crc actual_size _discard
  IFS=' ' read -r actual_crc actual_size _discard < <(cksum "${zip_path}")
  if [[ "${actual_crc}" != "${expected_crc}" || "${actual_size}" != "${expected_size}" ]]; then
    log_error "校验 ${zip_path} 失败（期望 crc=${expected_crc} size=${expected_size}，来源 ${expected_name}；实际 crc=${actual_crc} size=${actual_size}）"
    return 1
  fi
  log_success "安装介质校验已通过：${installer}"
}

# Return the udev-backed Oracle ASM disk glob used by this project.
#   $1 = 'p1'  → data partitions (P1)
#   $1 = 'p2'  → reco partitions (P2)
asm_disk_glob() {
  local part="$1"
  case "${part}" in
    p1) echo "/dev/ORCL_DISK*_p1" ;;
    p2) echo "/dev/ORCL_DISK*_p2" ;;
    *)
      log_error "不支持的 ASM 分区选择器：'${part}'"
      return 1
      ;;
  esac
}
