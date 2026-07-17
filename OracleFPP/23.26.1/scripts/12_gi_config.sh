#!/usr/bin/env bash
#------------------------------------------------------------------------------
# LICENSE UPL 1.0
# Copyright (c) 1982-2026 Oracle and/or its affiliates. All rights reserved.
#
# 12_gi_config.sh
#   Run gridSetup.sh -executeConfigTools to finalise the cluster (or ORestart)
#   configuration after the root scripts have completed.
#   Runs as the grid user.
#------------------------------------------------------------------------------
# 中文说明：
# 用于执行 gridSetup.sh 的配置阶段，并处理常见的返回码。

. /vagrant/scripts/_common.sh
require_user grid
for v in GI_HOME GRID_BASE ORA_INVENTORY ORA_LANGUAGES \
         CLUSTER_NAME SCAN_NAME SCAN_PORT \
         SYS_PASSWORD; do
  require_var "${v}"
done

data_disks="$(ls -dm $(asm_disk_glob p1) | tr -d ' \n')"
discovery_string="$(asm_disk_glob p1)"

# 中文：重用响应参数完成 executeConfigTools 阶段。
rsp_args=(
  INVENTORY_LOCATION="${ORA_INVENTORY}"
  SELECTED_LANGUAGES="${ORA_LANGUAGES}"
  ORACLE_BASE="${GRID_BASE}"
  oracle.install.asm.OSDBA=asmdba
  oracle.install.asm.OSOPER=asmoper
  oracle.install.asm.OSASM=asmadmin
  oracle.install.option=CRS_CONFIG
  oracle.install.crs.configureGIMR=true
  oracle.install.crs.config.scanType=LOCAL_SCAN
  oracle.install.crs.config.gpnp.scanName="${SCAN_NAME}"
  oracle.install.crs.config.gpnp.scanPort="${SCAN_PORT}"
  oracle.install.crs.config.clusterName="${CLUSTER_NAME}"
  oracle.install.crs.config.ClusterConfiguration=STANDALONE
  oracle.install.crs.config.configureAsExtendedCluster=false
  oracle.install.crs.config.gpnp.configureGNS=false
  oracle.install.crs.config.autoConfigureClusterNodeVIP=false
  oracle.install.asm.configureGIMRDataDG=false
  oracle.install.asmOnNAS.configureGIMRDataDG=false
  oracle.install.crs.config.useIPMI=false
  oracle.install.asm.storageOption=ASM
  oracle.install.asm.SYSASMPassword="${SYS_PASSWORD}"
  oracle.install.asm.monitorPassword="${SYS_PASSWORD}"
  oracle.install.asm.diskGroup.name=DATA
  oracle.install.asm.diskGroup.redundancy=EXTERNAL
  oracle.install.asm.diskGroup.AUSize=4
  oracle.install.asm.diskGroup.disks="${data_disks}"
  oracle.install.asm.diskGroup.diskDiscoveryString="${discovery_string}"
  oracle.install.asm.gimrDG.AUSize=1
  oracle.install.crs.configureRHPS=false
  oracle.install.crs.config.ignoreDownNodes=false
  oracle.install.config.managementOption=NONE
  oracle.install.config.omsPort=0
  oracle.install.crs.rootconfig.executeRootScript=false
)

log_section "正在运行 gridSetup.sh -executeConfigTools"
gridsetup_log="$(mktemp /tmp/gridSetup-executeConfigTools.XXXXXX.log)"
if "${GI_HOME}/gridSetup.sh" \
     -silent -executeConfigTools \
     -responseFile "${GI_HOME}/install/response/gridsetup.rsp" \
     "${rsp_args[@]}" 2>&1 | tee "${gridsetup_log}"; then
  rc=0
else
  rc=$?
fi

case "${rc}" in
  0) log_success "gridSetup.sh -executeConfigTools 已完成" ;;
  6) log_info    "gridSetup.sh -executeConfigTools 已完成 with warnings (exit=6)" ;;
  255)
    if grep -Fq '[INS-43080]' "${gridsetup_log}" \
       && grep -Fq 'Some of the configuration assistants failed, were cancelled or skipped.' "${gridsetup_log}"; then
      log_info "gridSetup.sh -executeConfigTools 报告 INS-43080（exit=255）；继续执行，并让后续 GI 检查验证整体状态"
    else
      log_error "gridSetup.sh -executeConfigTools 执行失败，exit=${rc}"
      exit "${rc}"
    fi
    ;;
  *) log_error   "gridSetup.sh -executeConfigTools 执行失败，exit=${rc}"; exit "${rc}" ;;
esac
