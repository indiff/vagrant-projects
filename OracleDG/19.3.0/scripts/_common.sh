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
__dg_on_err() {
  local exit_code=$?
  log_error "command failed (exit=${exit_code}) at ${BASH_SOURCE[1]:-?}:${BASH_LINENO[0]:-?} — '${BASH_COMMAND}'"
  exit "${exit_code}"
}
trap __dg_on_err ERR

# Source the runtime env file if present (not available during its own generation).
# It lives on the guest filesystem so it does not depend on /vagrant mount
# semantics, which vary between providers.
: "${DG_SETUP_ENV_FILE:=/etc/opt/oracle-dg/setup.env}"
if [[ -r "${DG_SETUP_ENV_FILE}" ]]; then
  # setup.env is trusted: written by this project's setup.sh
  # shellcheck disable=SC1090
  . "${DG_SETUP_ENV_FILE}"
elif [[ -e "${DG_SETUP_ENV_FILE}" ]]; then
  log_error "setup env '${DG_SETUP_ENV_FILE}' is not readable by user '$(id -un)'"
  exit 1
fi

# Helpers used by several scripts
require_root() {
  if [[ "$(id -u)" -ne 0 ]]; then
    log_error "this script must run as root"
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
