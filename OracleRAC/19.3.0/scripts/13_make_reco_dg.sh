#!/usr/bin/env bash
#------------------------------------------------------------------------------
# LICENSE UPL 1.0
# Copyright (c) 1982-2026 Oracle and/or its affiliates. All rights reserved.
#
# 13_make_reco_dg.sh
#   Create the +RECO diskgroup using the P2 partitions of each shared disk.
#   Runs as the grid user.
#------------------------------------------------------------------------------
# 中文说明：
# - 此脚本使用共享磁盘的 P2 分区创建 +RECO 磁盘组。
# - 仅翻译面向使用者的提示信息，保留命令、变量、路径与配置键原样。

. /vagrant/scripts/_common.sh
# 共享工具函数负责日志格式、参数校验与磁盘解析。
require_user grid
for v in GI_HOME GI_VERSION DB_VERSION ORESTART; do
  require_var "${v}"
done

export ORACLE_HOME="${GI_HOME}"
if [[ "${ORESTART}" == "true" ]]; then
  export ORACLE_SID='+ASM'
else
  export ORACLE_SID='+ASM1'
fi

# Build the SQL DISK clause — one entry per P2 device.
declare -a disk_devices=()
for d in /dev/ORCL_DISK*_p2; do
  [[ -e "${d}" ]] || continue
  disk_devices+=("${d}")
done

if (( ${#disk_devices[@]} == 0 )); then
  log_error "未找到用于 RECO 的 P2 设备"
  exit 1
fi

disk_clause=''
for dev in "${disk_devices[@]}"; do
  disk_clause+="  '${dev}',\n"
done
disk_clause="${disk_clause%,\\n}"   # strip trailing comma
disk_clause="$(printf '%b' "${disk_clause}")"

compat_asm="${GI_VERSION}"
compat_rdbms="${DB_VERSION}"

log_section "正在创建 +RECO 磁盘组（NORMAL 冗余）"
"${GI_HOME}/bin/sqlplus" -S / as sysasm <<EOF
WHENEVER SQLERROR EXIT SQL.SQLCODE;
SET ECHO ON
CREATE DISKGROUP RECO NORMAL REDUNDANCY
 DISK
${disk_clause}
 ATTRIBUTE
   'compatible.asm'   = '${compat_asm}',
   'compatible.rdbms' = '${compat_rdbms}',
   'sector_size'      = '512',
   'AU_SIZE'          = '4M',
   'content.type'     = 'recovery';
EXIT;
EOF
log_success "RECO 磁盘组已创建"
