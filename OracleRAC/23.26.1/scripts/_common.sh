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
: "${INFO:=\033[0;34mINFO: \033[0m}"
: "${ERROR:=\033[1;31mERROR: \033[0m}"
: "${SUCCESS:=\033[1;32mSUCCESS: \033[0m}"

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
  log_error "command failed (exit=${exit_code}) at ${BASH_SOURCE[1]:-?}:${BASH_LINENO[0]:-?} — '${BASH_COMMAND}'"
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
  log_error "setup env '${RAC_SETUP_ENV_FILE}' is not readable by user '$(id -un)'"
  exit 1
fi

require_root() {
  if [[ "$(id -u)" -ne 0 ]]; then
    log_error "this script must run as root"
    exit 1
  fi
}

require_user() {
  local want="$1"
  if [[ "$(id -un)" != "${want}" ]]; then
    log_error "this script must run as user '${want}' (current: '$(id -un)')"
    exit 1
  fi
}

require_var() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    log_error "required variable '${name}' is not set"
    exit 1
  fi
}

device_prefix_for_provider() {
  local provider="$1"
  case "${provider}" in
    libvirt)    printf '%s\n' 'vd' ;;
    virtualbox) printf '%s\n' 'sd' ;;
    *)          log_error "unsupported provider '${provider}'"; return 1 ;;
  esac
}

disk_suffix_from_index() {
  local idx="$1"
  if ! [[ "${idx}" =~ ^[0-9]+$ ]]; then
    log_error "disk index must be a non-negative integer (got: '${idx}')"
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
    log_error "disk index must be a non-negative integer (got: '${idx}')"
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
        log_error "no /dev/disk/by-path entry for SATA port index ${idx} (ata-${port})"
        return 1
      fi
      if (( ${#matches[@]} > 1 )); then
        log_error "multiple /dev/disk/by-path entries for ata-${port}: ${matches[*]}"
        return 1
      fi
      path="$(readlink -f "${matches[0]}")"
      ;;
    *)
      log_error "unsupported provider '${provider}'"
      return 1
      ;;
  esac

  if [[ ! -b "${path}" ]]; then
    log_error "resolved device ${path} for disk index ${idx} is not a block device"
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

  log_error "timed out waiting for block device ${path}"
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
    log_error "timed out waiting for block device ${path} before chown"
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

  [[ -f "${zip_path}" ]] || { log_error "installer zip not found at ${zip_path}"; return 1; }
  [[ -f "${manifest}" ]] || { log_error "checksum manifest not found at ${manifest}"; return 1; }

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
    log_error "no checksum entry for ${installer} found in ${manifest}"
    return 1
  fi
  if ! [[ "${expected_crc}" =~ ^[0-9]+$ && "${expected_size}" =~ ^[0-9]+$ ]]; then
    log_error "invalid checksum entry for ${installer} in ${manifest}"
    return 1
  fi

  log_section "Verifying ${installer} against ${manifest}"
  local actual_crc actual_size _discard
  IFS=' ' read -r actual_crc actual_size _discard < <(cksum "${zip_path}")
  if [[ "${actual_crc}" != "${expected_crc}" || "${actual_size}" != "${expected_size}" ]]; then
    log_error "checksum verification failed for ${zip_path} (expected crc=${expected_crc} size=${expected_size} from ${expected_name}, got crc=${actual_crc} size=${actual_size})"
    return 1
  fi
  log_success "Installer checksum verified: ${installer}"
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
      log_error "unsupported ASM partition selector '${part}'"
      return 1
      ;;
  esac
}
