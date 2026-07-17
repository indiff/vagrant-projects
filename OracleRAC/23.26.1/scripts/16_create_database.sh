#!/usr/bin/env bash
#------------------------------------------------------------------------------
# LICENSE UPL 1.0
# Copyright (c) 1982-2026 Oracle and/or its affiliates. All rights reserved.
#
# 16_create_database.sh
#   Create the RAC / RACOne / SI database via dbca (silent). Runs as oracle.
#------------------------------------------------------------------------------
# 中文说明：
# - 此脚本通过 dbca 静默创建 RAC、RAC One Node 或单实例数据库。
# - 仅翻译面向使用者的提示信息，保留命令、变量、路径与配置键原样。

. /vagrant/scripts/_common.sh
# 共享工具函数负责日志格式、参数校验与磁盘解析。
require_user oracle
for v in DB_HOME DB_NAME DB_TYPE CDB ORESTART SYS_PASSWORD \
         DB_RECOVERY_FILE_DEST_SIZE NODE1_HOSTNAME; do
  require_var "${v}"
done

log_info "Using DBCA fast recovery area size '${DB_RECOVERY_FILE_DEST_SIZE}'"

dbca_args=(
  -silent -createDatabase
  -templateName General_Purpose.dbc
  -initParams "db_recovery_file_dest_size=${DB_RECOVERY_FILE_DEST_SIZE}"
  -responseFile NO_VALUE
  -gdbname "${DB_NAME}"
  -characterSet AL32UTF8
  -sysPassword    "${SYS_PASSWORD}"
  -systemPassword "${SYS_PASSWORD}"
  -databaseType MULTIPURPOSE
  -automaticMemoryManagement false
  -totalMemory 2048
  -redoLogFileSize 50
  -emConfiguration NONE
  -ignorePreReqs
  -storageType ASM
  -diskGroupName +DATA
  -recoveryGroupName +RECO
  -asmsnmpPassword "${SYS_PASSWORD}"
)

if [[ "${CDB}" == "true" ]]; then
  require_var PDB_NAME
  require_var PDB_PASSWORD
  dbca_args+=(
    -createAsContainerDatabase true
    -numberOfPDBs 1
    -pdbName "${PDB_NAME}"
    -pdbAdminPassword "${PDB_PASSWORD}"
  )
fi

case "${DB_TYPE}" in
  RAC)
    dbca_args+=(-databaseConfigType RAC)
    ;;
  RACONE)
    dbca_args+=(-databaseConfigType RACONE -RACOneNodeServiceName "${DB_NAME}_srv")
    ;;
  SI)
    dbca_args+=(-databaseConfigType SINGLE)
    ;;
  *)
    log_error "未预期的 DB_TYPE='${DB_TYPE}'"
    exit 1
    ;;
esac

if [[ "${DB_TYPE}" == "RAC" || "${DB_TYPE}" == "RACONE" ]]; then
  if [[ "${ORESTART}" == "false" ]]; then
    require_var NODE2_HOSTNAME
    dbca_args+=(-nodelist "${NODE1_HOSTNAME},${NODE2_HOSTNAME}")
  else
    dbca_args+=(-nodelist "$(hostname -s)")
  fi
fi

log_section "正在运行 dbca（静默模式，createDatabase）"
"${DB_HOME}/bin/dbca" "${dbca_args[@]}"
log_success "数据库 ${DB_NAME} 已创建"
