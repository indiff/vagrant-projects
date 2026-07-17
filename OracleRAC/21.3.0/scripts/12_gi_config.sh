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
# - 此脚本执行 Grid Infrastructure 配置工具，完成集群或 Oracle Restart 配置。
# - 仅翻译面向使用者的提示信息，保留命令、变量、路径与配置键原样。

. /vagrant/scripts/_common.sh
# 共享工具函数负责日志格式、参数校验与磁盘解析。
require_user grid
for v in GI_HOME GRID_BASE ORA_INVENTORY ORA_LANGUAGES \
         CLUSTER_NAME SCAN_NAME SCAN_PORT \
         NOMGMTDB ORESTART SYS_PASSWORD; do
  require_var "${v}"
done

data_disks="$(ls -dm $(asm_disk_glob p1) | tr -d ' \n')"
if [[ -z "${data_disks}" ]]; then
  log_error "使用 glob 未找到 DATA 磁盘 '$(asm_disk_glob p1)'"
  exit 1
fi
discovery_string="$(asm_disk_glob p1)"

log_info "Using ASM DATA discovery string '${discovery_string}'"
log_info "Using ASM DATA disks '${data_disks}'"

# 将静默安装所需参数集中组装，便于根据拓扑补充分支配置。
rsp_args=(
  INVENTORY_LOCATION="${ORA_INVENTORY}"
  SELECTED_LANGUAGES="${ORA_LANGUAGES}"
  ORACLE_BASE="${GRID_BASE}"
  oracle.install.asm.OSDBA=asmdba
  oracle.install.asm.OSOPER=asmoper
  oracle.install.asm.OSASM=asmadmin
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

if [[ "${ORESTART}" == "true" ]]; then
  rsp_args+=(oracle.install.option=HA_CONFIG)
else
  rsp_args+=(
    oracle.install.option=CRS_CONFIG
    oracle.install.crs.config.scanType=LOCAL_SCAN
    oracle.install.crs.config.gpnp.scanName="${SCAN_NAME}"
    oracle.install.crs.config.gpnp.scanPort="${SCAN_PORT}"
    oracle.install.crs.config.clusterName="${CLUSTER_NAME}"
  )
fi

if [[ "${NOMGMTDB}" == "true" ]]; then
  rsp_args+=(oracle_install_crs_ConfigureMgmtDB=false)
else
  rsp_args+=(oracle_install_crs_ConfigureMgmtDB=true)
fi

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
      log_info "gridSetup.sh -executeConfigTools 报告 INS-43080（exit=255）；继续执行，并交由后续 GI 检查验证堆栈状态"
    else
      log_error "gridSetup.sh -executeConfigTools 失败，exit=${rc}"
      exit "${rc}"
    fi
    ;;
  *) log_error   "gridSetup.sh -executeConfigTools 失败，exit=${rc}"; exit "${rc}" ;;
esac
