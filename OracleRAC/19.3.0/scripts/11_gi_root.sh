#!/usr/bin/env bash
#------------------------------------------------------------------------------
# LICENSE UPL 1.0
# Copyright (c) 1982-2026 Oracle and/or its affiliates. All rights reserved.
#
# 11_gi_root.sh
#   Run orainstRoot.sh + root.sh on both cluster nodes (or just locally for
#   Oracle Restart).
#------------------------------------------------------------------------------
# 中文说明：
# - 此脚本在本地和远端节点运行 GI 所需的 root 脚本。
# - 仅翻译面向使用者的提示信息，保留命令、变量、路径与配置键原样。

. /vagrant/scripts/_common.sh
# 共享工具函数负责日志格式、参数校验与磁盘解析。
require_root
require_var ORA_INVENTORY
require_var GI_HOME
require_var ORESTART

log_section "正在本地节点运行 orainstRoot.sh"
sh "${ORA_INVENTORY}/orainstRoot.sh"

log_section "正在本地节点运行 root.sh"
sh "${GI_HOME}/root.sh"

if [[ "${ORESTART}" == "true" ]]; then
  log_section "正在运行 roothas.pl（Oracle Restart）"
  "${GI_HOME}/perl/bin/perl" \
    -I "${GI_HOME}/perl/lib" -I "${GI_HOME}/crs/install" \
    "${GI_HOME}/crs/install/roothas.pl"
else
  require_var NODE2_HOSTNAME
  log_section "正在 ${NODE2_HOSTNAME} 上运行 orainstRoot.sh 和 root.sh"
  ssh -o StrictHostKeyChecking=no "root@${NODE2_HOSTNAME}" "sh ${ORA_INVENTORY}/orainstRoot.sh"
  ssh -o StrictHostKeyChecking=no "root@${NODE2_HOSTNAME}" "sh ${GI_HOME}/root.sh"
fi
