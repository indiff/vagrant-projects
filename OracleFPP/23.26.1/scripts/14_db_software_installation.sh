#!/usr/bin/env bash
#------------------------------------------------------------------------------
# LICENSE UPL 1.0
# Copyright (c) 1982-2026 Oracle and/or its affiliates. All rights reserved.
#
# 15_db_software_installation.sh
#   Silent, software-only RDBMS install (EE, cluster-aware). Runs as oracle.
#------------------------------------------------------------------------------
# 中文说明：
# 用于静默安装数据库软件二进制，而不在此阶段建库。

. /vagrant/scripts/_common.sh
require_user grid
for v in DB_HOME DB_BASE ORA_INVENTORY ORA_LANGUAGES \
         NODE1_HOSTNAME; do
  require_var "${v}"
done

# 中文：组装软件安装参数，确保后续 root.sh 有一致的安装目录。
rsp_args=(
  oracle.install.option=INSTALL_DB_SWONLY
  UNIX_GROUP_NAME=oinstall
  INVENTORY_LOCATION="${ORA_INVENTORY}"
  SELECTED_LANGUAGES="${ORA_LANGUAGES}"
  ORACLE_HOME="${DB_HOME}"
  ORACLE_BASE="${DB_BASE}"
  oracle.install.db.InstallEdition=EE
  oracle.install.db.OSDBA_GROUP=dba
  oracle.install.db.OSBACKUPDBA_GROUP=backupdba
  oracle.install.db.OSDGDBA_GROUP=dgdba
  oracle.install.db.OSKMDBA_GROUP=kmdba
  oracle.install.db.OSRACDBA_GROUP=racdba
  oracle.install.db.rac.serverpoolCardinality=0
  oracle.install.db.config.starterdb.type=GENERAL_PURPOSE
  oracle.install.db.ConfigureAsContainerDB=true
  oracle.install.db.CLUSTER_NODES="${NODE1_HOSTNAME}"
  oracle.install.db.isRACOneInstall=false
  SECURITY_UPDATES_VIA_MYORACLESUPPORT=false
  DECLINE_SECURITY_UPDATES=true
)

log_section "正在运行 runInstaller（仅安装软件，静默模式）"
if "${DB_HOME}/runInstaller" \
     -ignorePrereq -waitforcompletion -silent \
     -responseFile "${DB_HOME}/install/response/db_install.rsp" \
     "${rsp_args[@]}"; then
  rc=0
else
  rc=$?
fi

case "${rc}" in
  0) log_success "runInstaller 已成功完成" ;;
  6) log_info    "runInstaller 已完成但带有告警（exit=6）；设置 -ignorePrereq 时属预期情况" ;;
  *) log_error   "runInstaller 执行失败，exit=${rc}"; exit "${rc}" ;;
esac
