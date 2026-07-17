#!/usr/bin/env bash
#------------------------------------------------------------------------------
# LICENSE UPL 1.0
# Copyright (c) 1982-2026 Oracle and/or its affiliates. All rights reserved.
#
# 10_gi_installation.sh
#   Run gridSetup.sh in silent mode — software install + cluster/HA
#   configuration up to the point where root scripts must be executed.
#   Runs as the grid user.
#------------------------------------------------------------------------------
# 中文说明：
# - 此脚本以静默模式执行 Grid Infrastructure 软件安装与初始配置。
# - 仅翻译面向使用者的提示信息，保留命令、变量、路径与配置键原样。

. /vagrant/scripts/_common.sh
# 共享工具函数负责日志格式、参数校验与磁盘解析。
require_user grid
for v in GI_HOME GRID_BASE ORA_INVENTORY ORA_LANGUAGES \
         CLUSTER_NAME SCAN_NAME SCAN_PORT \
         NOMGMTDB ORESTART \
         NODE1_HOSTNAME NODE1_FQ_HOSTNAME NODE1_FQ_VIPNAME \
         PUBLIC_SUBNET PRIVATE_SUBNET SYS_PASSWORD; do
  require_var "${v}"
done

# Network interface names (ip -br link = portable across OL7/8/9).
net_device1="$(ip -o link show | awk -F': ' 'NR==3 {print $2}' | awk '{print $1}' | sed 's/@.*$//')"
net_device2="$(ip -o link show | awk -F': ' 'NR==4 {print $2}' | awk '{print $1}' | sed 's/@.*$//')"
if [[ -z "${net_device1}" || -z "${net_device2}" ]]; then
  log_error "无法识别网卡设备（得到：'${net_device1}' / '${net_device2}'）"
  exit 1
fi

# Data disks (P1 partitions) for the initial DATA diskgroup.
data_disks="$(ls -dm $(asm_disk_glob p1) | tr -d ' \n')"
if [[ -z "${data_disks}" ]]; then
  log_error "使用 glob 未找到 DATA 磁盘 '$(asm_disk_glob p1)'"
  exit 1
fi
discovery_string="$(asm_disk_glob p1)"

log_info "Using ASM DATA discovery string '${discovery_string}'"
log_info "Using ASM DATA disks '${data_disks}'"

# --- Assemble rsp parameters ------------------------------------------------
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
  require_var NODE2_HOSTNAME
  require_var NODE2_FQ_HOSTNAME
  require_var NODE2_FQ_VIPNAME
  rsp_args+=(
    oracle.install.option=CRS_CONFIG
    oracle.install.crs.config.scanType=LOCAL_SCAN
    oracle.install.crs.config.gpnp.scanName="${SCAN_NAME}"
    oracle.install.crs.config.gpnp.scanPort="${SCAN_PORT}"
    oracle.install.crs.config.clusterName="${CLUSTER_NAME}"
    oracle.install.crs.config.clusterNodes="${NODE1_FQ_HOSTNAME}:${NODE1_FQ_VIPNAME}:HUB,${NODE2_FQ_HOSTNAME}:${NODE2_FQ_VIPNAME}:HUB"
    oracle.install.crs.config.networkInterfaceList="${net_device1}:${PUBLIC_SUBNET}:1,${net_device2}:${PRIVATE_SUBNET}:5"
  )
fi

if [[ "${NOMGMTDB}" == "true" ]]; then
  rsp_args+=(oracle_install_crs_ConfigureMgmtDB=false)
else
  rsp_args+=(oracle_install_crs_ConfigureMgmtDB=true)
fi

log_section "正在运行 gridSetup.sh（静默模式，-ignorePrereq）"

# gridSetup.sh exit codes:
#   0  success
#   6  success with warnings (typical when -ignorePrereq bypasses checks)
if "${GI_HOME}/gridSetup.sh" \
     -ignorePrereq -waitforcompletion -silent \
     -responseFile "${GI_HOME}/install/response/gridsetup.rsp" \
     "${rsp_args[@]}"; then
  rc=0
else
  rc=$?
fi

case "${rc}" in
  0) log_success "gridSetup.sh 已成功完成" ;;
  6) log_info    "gridSetup.sh 已完成，但带有警告（exit=6）；设置 -ignorePrereq 时这是预期行为" ;;
  *) log_error   "gridSetup.sh 失败，exit=${rc}"; exit "${rc}" ;;
esac
