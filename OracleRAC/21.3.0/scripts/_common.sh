#!/usr/bin/env bash
# shellcheck shell=bash
#------------------------------------------------------------------------------
# LICENSE UPL 1.0
# Copyright (c) 1982-2026 Oracle and/or its affiliates. All rights reserved.
#
# _common.sh
#   Shared helpers for all RAC provisioning scripts.
#   Must be sourced, not executed:  . /vagrant/scripts/_common.sh
# 共享工具函数负责日志格式、参数校验与磁盘解析。
#------------------------------------------------------------------------------

# Re-entrancy guard
# 中文说明：
# - 此脚本提供 RAC 预配流程共享的日志、校验、磁盘解析和校验和工具函数。
# - 仅翻译面向使用者的提示信息，保留命令、变量、路径与配置键原样。

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
: "${INFO:=\033[0;34m信息：\033[0m}"
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
  log_error "命令执行失败（exit=${exit_code}），位置 ${BASH_SOURCE[1]:-?}:${BASH_LINENO[0]:-?} —— '${BASH_COMMAND}'"
  exit "${exit_code}"
}
trap __rac_on_err ERR

# Runtime env file. Lives on the guest filesystem (not /vagrant) so the
# oracle/grid users can source it without the provider-specific
# synced-folder permission quirks.
: "${RAC_SETUP_ENV_FILE:=/etc/opt/oracle-rac/setup.env}"
if [[ -r "${RAC_SETUP_ENV_FILE}" ]]; then
  # setup.env is trusted: written by this project's setup.sh
  # shellcheck disable=SC1090
  . "${RAC_SETUP_ENV_FILE}"
elif [[ -e "${RAC_SETUP_ENV_FILE}" ]]; then
  log_error "用户 '$(id -un)' 无法读取 setup env '${RAC_SETUP_ENV_FILE}'"
  exit 1
fi

require_root() {
  if [[ "$(id -u)" -ne 0 ]]; then
    log_error "此脚本必须以 root 身份运行"
    exit 1
  fi
}

require_user() {
  local want="$1"
  if [[ "$(id -un)" != "${want}" ]]; then
    log_error "此脚本必须以用户 '${want}' 身份运行（当前用户：'$(id -un)'）"
    exit 1
  fi
}

require_var() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    log_error "未设置必需变量 '${name}'"
    exit 1
  fi
}

device_prefix_for_provider() {
  local provider="$1"
  case "${provider}" in
    libvirt)    printf '%s\n' 'vd' ;;
    virtualbox) printf '%s\n' 'sd' ;;
    *)          log_error "不支持的 provider '${provider}'"; return 1 ;;
  esac
}

disk_suffix_from_index() {
  local idx="$1"
  if ! [[ "${idx}" =~ ^[0-9]+$ ]]; then
    log_error "磁盘索引必须是非负整数（当前值：'${idx}'）"
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

# Resolve a disk attached at attachment-index ${idx} (0-based) to its current
# /dev path on the running guest.
#
# libvirt uses virtio (vd<letter>) which the kernel enumerates in attachment
# order, so we keep the letter math.
#
# virtualbox uses SATA AHCI; the kernel discovers targets asynchronously and
# may produce sd<letter> names that do not follow the SATA port order.  We
# resolve through /dev/disk/by-path/pci-*-ata-N where N = idx + 1, which the
# kernel populates from the SATA port number itself and is therefore stable.
resolve_disk_device() {
  local idx="$1"
  local provider="$2"
  local prefix letter path

  if ! [[ "${idx}" =~ ^[0-9]+$ ]]; then
    log_error "磁盘索引必须是非负整数（当前值：'${idx}'）"
    return 1
  fi

  prefix="$(device_prefix_for_provider "${provider}")" || return 1

  case "${provider}" in
    libvirt)
      letter="$(disk_suffix_from_index "${idx}")" || return 1
      path="/dev/${prefix}${letter}"
      ;;
    virtualbox)
      local port=$((idx + 1))
      local matches=()
      shopt -s nullglob
      matches=( /dev/disk/by-path/pci-*-ata-"${port}" )
      shopt -u nullglob
      if (( ${#matches[@]} == 0 )); then
        log_error "SATA 端口索引缺少对应的 /dev/disk/by-path 条目 ${idx} (ata-${port})"
        return 1
      fi
      if (( ${#matches[@]} > 1 )); then
        log_error "ata- 对应存在多个 /dev/disk/by-path 条目：${port}: ${matches[*]}"
        return 1
      fi
      path="$(readlink -f "${matches[0]}")"
      ;;
    *)
      log_error "不支持的 provider '${provider}'"
      return 1
      ;;
  esac

  if [[ ! -b "${path}" ]]; then
    log_error "为磁盘索引 ${idx} 解析得到的设备 ${path} 不是块设备"
    return 1
  fi

  printf '%s\n' "${path}"
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
    log_error "等待块设备 ${path} 超时 before chown"
    return 1
  fi

  chown "${owner_group}" "${path}"
}

# Verify an installer zip against the project's db_installer.cksum manifest.
# Args: $1 = zip basename (e.g. LINUX.X64_2326100_db_home.zip)
verify_installer_cksum() {
  local installer="$1"
  local zip_path="/vagrant/ORCL_software/${installer}"
  local manifest="/vagrant/db_installer.cksum"

  [[ -f "${zip_path}" ]] || { log_error "未在 ${zip_path} 找到安装 zip 包"; return 1; }
  [[ -f "${manifest}" ]] || { log_error "未在 ${manifest} 找到校验清单"; return 1; }

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
    log_error "未在 ${manifest} 中找到 ${installer} 的校验条目"
    return 1
  fi
  if ! [[ "${expected_crc}" =~ ^[0-9]+$ && "${expected_size}" =~ ^[0-9]+$ ]]; then
    log_error "${manifest} 中 ${installer} 的校验条目无效"
    return 1
  fi

  log_section "正在根据 ${manifest} 校验 ${installer}"
  local actual_crc actual_size _discard
  IFS=' ' read -r actual_crc actual_size _discard < <(cksum "${zip_path}")
  if [[ "${actual_crc}" != "${expected_crc}" || "${actual_size}" != "${expected_size}" ]]; then
    log_error "${zip_path} 的校验失败 (expected crc=${expected_crc} size=${expected_size} from ${expected_name}, got crc=${actual_crc} size=${actual_size})"
    return 1
  fi
  log_success "安装介质校验通过：${installer}"
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
      log_error "不支持的 ASM 分区选择器 '${part}'"
      return 1
      ;;
  esac
}
