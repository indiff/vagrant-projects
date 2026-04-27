#!/usr/bin/env bash
#------------------------------------------------------------------------------
# LICENSE UPL 1.0
# Copyright (c) 1982-2026 Oracle and/or its affiliates. All rights reserved.
#
# 06_do_RDBMS_software_installation.sh
#   Extracts the Oracle Home zip into DB_HOME and runs the silent installer
#   (software-only install). Verifies the installer against the project's
#   db_installer.cksum manifest before extraction.
#
#   Runs as the oracle user.
#------------------------------------------------------------------------------
. /vagrant/scripts/_common.sh

if [[ "$(id -un)" != "oracle" ]]; then
  log_error "this script must run as the oracle user"
  exit 1
fi

require_var DB_HOME
require_var DB_BASE
require_var DB_SOFTWARE
require_var ORA_INVENTORY
require_var ORA_LANGUAGES

zip_path="/vagrant/ORCL_software/${DB_SOFTWARE}"
checksum_path="/vagrant/db_installer.cksum"

if [[ ! -f "${zip_path}" ]]; then
  log_error "installer zip not found at ${zip_path}"
  exit 1
fi

if [[ ! -f "${checksum_path}" ]]; then
  log_error "installer checksum file not found at ${checksum_path}"
  exit 1
fi

expected_crc=''
expected_size=''
expected_name=''

while IFS= read -r line; do
  [[ -z "${line}" || "${line}" == \#* ]] && continue

  IFS=' ' read -r entry_crc entry_size entry_name <<< "${line}"
  if [[ "${entry_name##*/}" == "${DB_SOFTWARE}" ]]; then
    expected_crc="${entry_crc}"
    expected_size="${entry_size}"
    expected_name="${entry_name}"
    break
  fi
done < "${checksum_path}"

if [[ -z "${expected_crc}" || -z "${expected_size}" ]]; then
  log_error "no checksum entry for ${DB_SOFTWARE} found in ${checksum_path}"
  exit 1
fi

if ! [[ "${expected_crc}" =~ ^[0-9]+$ && "${expected_size}" =~ ^[0-9]+$ ]]; then
  log_error "invalid checksum entry for ${DB_SOFTWARE} in ${checksum_path}"
  exit 1
fi

log_section "Verifying ${DB_SOFTWARE} against ${checksum_path}"
IFS=' ' read -r actual_crc actual_size _ < <(cksum "${zip_path}")
if [[ "${actual_crc}" != "${expected_crc}" || "${actual_size}" != "${expected_size}" ]]; then
  log_error "checksum verification failed for ${zip_path} (expected crc=${expected_crc} size=${expected_size} from ${expected_name}, got crc=${actual_crc} size=${actual_size})"
  exit 1
fi
log_success "Installer checksum verified"

log_section "Extracting ${DB_SOFTWARE} into ${DB_HOME}"
mkdir -p "${DB_HOME}"
cd "${DB_HOME}"
unzip -oq "${zip_path}"

log_section "Running runInstaller (software-only, silent)"

# runInstaller exit codes (see Oracle docs):
#   0  success
#   6  successful with warnings — typical when -ignorePrereq is set
#      (prerequisite checks bypassed, install still complete)
#   other  real failure
#
# Wrap the command in an if-statement so Oracle's warning exit code (6)
# can be handled explicitly without tripping the shared ERR trap from
# _common.sh before we inspect rc.
if "${DB_HOME}/runInstaller" \
  -ignorePrereq -waitforcompletion -silent \
  -responseFile "${DB_HOME}/install/response/db_install.rsp" \
  oracle.install.option=INSTALL_DB_SWONLY \
  UNIX_GROUP_NAME=oinstall \
  INVENTORY_LOCATION="${ORA_INVENTORY}" \
  SELECTED_LANGUAGES="${ORA_LANGUAGES}" \
  ORACLE_HOME="${DB_HOME}" \
  ORACLE_BASE="${DB_BASE}" \
  oracle.install.db.InstallEdition=EE \
  oracle.install.db.OSDBA_GROUP=dba \
  oracle.install.db.OSBACKUPDBA_GROUP=backupdba \
  oracle.install.db.OSDGDBA_GROUP=dgdba \
  oracle.install.db.OSKMDBA_GROUP=kmdba \
  oracle.install.db.OSRACDBA_GROUP=racdba \
  SECURITY_UPDATES_VIA_MYORACLESUPPORT=false \
  DECLINE_SECURITY_UPDATES=true; then
  rc=0
else
  rc=$?
fi

case "${rc}" in
  0) log_success "runInstaller completed successfully" ;;
  6) log_info    "runInstaller completed with warnings (exit=6) — expected when -ignorePrereq is set" ;;
  *) log_error   "runInstaller failed with exit=${rc}"; exit "${rc}" ;;
esac
