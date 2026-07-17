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

# 中文说明：
# - 校验 Oracle 数据库安装 zip 的 cksum 后再执行解压和静默安装。
# - 允许 runInstaller 以带警告的退出码 6 结束，避免误判失败。

. /vagrant/scripts/_common.sh

if [[ "$(id -un)" != "oracle" ]]; then
  log_error "该脚本必须以 oracle 用户运行"
  exit 1
fi

require_var DB_HOME
require_var DB_BASE
require_var DB_SOFTWARE
require_var ORA_INVENTORY
require_var ORA_LANGUAGES

# 中文：先核对安装介质和校验清单，避免用错版本或损坏的 zip。
zip_path="/vagrant/ORCL_software/${DB_SOFTWARE}"
checksum_path="/vagrant/db_installer.cksum"

if [[ ! -f "${zip_path}" ]]; then
  log_error "未在 ${zip_path} 找到安装 zip"
  exit 1
fi

if [[ ! -f "${checksum_path}" ]]; then
  log_error "未在 ${checksum_path} 找到安装校验文件"
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
  log_error "在 ${checksum_path} 中未找到 ${DB_SOFTWARE} 的校验条目"
  exit 1
fi

if ! [[ "${expected_crc}" =~ ^[0-9]+$ && "${expected_size}" =~ ^[0-9]+$ ]]; then
  log_error "${checksum_path} 中 ${DB_SOFTWARE} 的校验条目无效"
  exit 1
fi

log_section "使用 ${checksum_path} 校验 ${DB_SOFTWARE}"
IFS=' ' read -r actual_crc actual_size _ < <(cksum "${zip_path}")
if [[ "${actual_crc}" != "${expected_crc}" || "${actual_size}" != "${expected_size}" ]]; then
  log_error "${zip_path} 校验失败（期望来自 ${expected_name} 的 crc=${expected_crc} size=${expected_size}，实际为 crc=${actual_crc} size=${actual_size}）"
  exit 1
fi
log_success "安装介质校验通过"

log_section "将 ${DB_SOFTWARE} 解压到 ${DB_HOME}"
mkdir -p "${DB_HOME}"
cd "${DB_HOME}"
unzip -oq "${zip_path}"

log_section "运行 runInstaller（仅安装软件，静默模式）"

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

# 中文：显式处理 Oracle Installer 的特殊退出码 6。
case "${rc}" in
  0) log_success "runInstaller 已成功完成" ;;
  6) log_info    "runInstaller 已完成但带有警告（exit=6），这是设置 -ignorePrereq 时的预期行为" ;;
  *) log_error   "runInstaller 失败，退出码=${rc}"; exit "${rc}" ;;
esac
