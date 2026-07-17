#!/usr/bin/env bash
#------------------------------------------------------------------------------
# LICENSE UPL 1.0
# Copyright (c) 1982-2026 Oracle and/or its affiliates. All rights reserved.
#
# standby_DB_setup.sh
#   Builds the standby database via RMAN DUPLICATE ... FROM ACTIVE DATABASE,
#   registers it in the Data Guard broker, and (optionally) opens it as ADG.
#
#   Credentials are NEVER passed on the command line — RMAN/DGMGRL take them
#   via CONNECT statements inside the heredoc, which keeps them out of `ps`.
#
#   Runs as the oracle user.
#------------------------------------------------------------------------------

# 中文说明：
# - 通过 RMAN 活动复制创建备库，并把它注册到 Data Guard broker。
# - 可根据 ADG 开关决定以只读应用模式或普通挂载模式启动备库。

. /vagrant/scripts/_common.sh

if [[ "$(id -un)" != "oracle" ]]; then
  log_error "该脚本必须以 oracle 用户运行"
  exit 1
fi

require_var DB_HOME
require_var DB_BASE
require_var DB_NAME
require_var SYS_PASSWORD
require_var CDB
require_var ADG
require_var NODE2_HOSTNAME

export ORACLE_HOME="${DB_HOME}"
export ORACLE_SID="${DB_NAME}"

sqlplus_sysdba() { "${DB_HOME}/bin/sqlplus" -s -L / as sysdba; }

# 中文：先准备目录与口令文件，满足 RMAN DUPLICATE 的启动条件。
log_section "准备备库目录和口令文件"
if [[ "${CDB}" == "true" ]]; then
  mkdir -p "/u02/oradata/${DB_NAME}/pdbseed"
  mkdir -p "/u02/oradata/${DB_NAME}/pdb1"
fi
mkdir -p "${DB_BASE}/fast_recovery_area/${DB_NAME}"
mkdir -p "${DB_BASE}/admin/${DB_NAME}/adump"

# orapwd accepts the password via command line — restrict visibility to this
# user only by chmod'ing the file, and keep the invocation brief.
"${DB_HOME}/bin/orapwd" \
  file="${ORACLE_HOME}/dbs/orapw${DB_NAME}" \
  password="${SYS_PASSWORD}" \
  entries=10 \
  format=12
chmod 0600 "${ORACLE_HOME}/dbs/orapw${DB_NAME}"

log_section "为辅助实例写入启动 pfile"
cat > /tmp/init_standby.ora <<EOF
*.db_name='${DB_NAME}'
*.local_listener='LISTENER'
EOF
chmod 0600 /tmp/init_standby.ora

log_section "启动辅助实例（NOMOUNT）"
sqlplus_sysdba <<'EOF'
WHENEVER SQLERROR EXIT FAILURE
STARTUP NOMOUNT PFILE='/tmp/init_standby.ora';
exit;
EOF

log_section "通过 RMAN 将主库复制为备库"
# Pass the password via CONNECT inside the heredoc — not visible to `ps`.
"${DB_HOME}/bin/rman" <<EOF
CONNECT TARGET    sys/"${SYS_PASSWORD}"@${DB_NAME};
CONNECT AUXILIARY sys/"${SYS_PASSWORD}"@${DB_NAME}_STDBY;
DUPLICATE TARGET DATABASE
  FOR STANDBY
  FROM ACTIVE DATABASE
  DORECOVER
  SPFILE
    SET db_unique_name='${DB_NAME}_STDBY' COMMENT 'Standby'
  NOFILENAMECHECK;
exit;
EOF

log_section "设置备库的 local_listener"
sqlplus_sysdba <<EOF
WHENEVER SQLERROR EXIT FAILURE
ALTER SYSTEM SET local_listener='(ADDRESS=(PROTOCOL=TCP)(HOST=${NODE2_HOSTNAME})(PORT=1521))' SCOPE=BOTH;
exit;
EOF

log_section "在备库上启用 Data Guard broker"
sqlplus_sysdba <<'EOF'
WHENEVER SQLERROR EXIT FAILURE
ALTER SYSTEM SET dg_broker_start=TRUE SCOPE=BOTH;
exit;
EOF

log_section "应用 Data Guard 调优参数"
sqlplus_sysdba <<'EOF'
WHENEVER SQLERROR EXIT FAILURE
ALTER SYSTEM SET ARCHIVE_LAG_TARGET=0             SCOPE=BOTH SID='*';
ALTER SYSTEM SET LOG_ARCHIVE_MAX_PROCESSES=4      SCOPE=BOTH SID='*';
ALTER SYSTEM SET LOG_ARCHIVE_MIN_SUCCEED_DEST=1   SCOPE=BOTH SID='*';
ALTER SYSTEM SET DATA_GUARD_SYNC_LATENCY=0        SCOPE=BOTH SID='*';
exit;
EOF

log_section "创建 DG broker 配置"
"${DB_HOME}/bin/dgmgrl" <<EOF
CONNECT sys/"${SYS_PASSWORD}"@${DB_NAME};
CREATE CONFIGURATION db_broker_config AS PRIMARY DATABASE IS ${DB_NAME} CONNECT IDENTIFIER IS ${DB_NAME};
exit;
EOF
sleep 10

"${DB_HOME}/bin/dgmgrl" <<EOF
CONNECT sys/"${SYS_PASSWORD}"@${DB_NAME};
ADD DATABASE ${DB_NAME}_STDBY AS CONNECT IDENTIFIER IS ${DB_NAME}_STDBY;
exit;
EOF
sleep 5

"${DB_HOME}/bin/dgmgrl" <<EOF
CONNECT sys/"${SYS_PASSWORD}"@${DB_NAME};
ENABLE CONFIGURATION;
exit;
EOF
sleep 5

if [[ "${ADG}" == "true" ]]; then
  log_section "以 Active Data Guard 模式打开备库（只读 + apply）"
  sqlplus_sysdba <<'EOF'
WHENEVER SQLERROR EXIT FAILURE
STARTUP MOUNT FORCE;
ALTER DATABASE OPEN READ ONLY;
ALTER DATABASE RECOVER MANAGED STANDBY DATABASE DISCONNECT FROM SESSION;
exit;
EOF
else
  log_section "以 MOUNT 状态启动备库"
  sqlplus_sysdba <<'EOF'
WHENEVER SQLERROR EXIT FAILURE
STARTUP MOUNT FORCE;
exit;
EOF
fi

log_section "输出最终 broker 状态（约 60 秒收敛）"
sleep 60
"${DB_HOME}/bin/dgmgrl" <<EOF
CONNECT sys/"${SYS_PASSWORD}"@${DB_NAME};
SHOW CONFIGURATION;
SHOW DATABASE ${DB_NAME};
SHOW DATABASE ${DB_NAME}_STDBY;
exit;
EOF

log_success "备库数据库配置完成"
