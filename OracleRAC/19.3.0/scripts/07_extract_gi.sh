#!/usr/bin/env bash
#------------------------------------------------------------------------------
# LICENSE UPL 1.0
# Copyright (c) 1982-2026 Oracle and/or its affiliates. All rights reserved.
#
# 07_extract_gi.sh
#   Verify and extract the Grid Infrastructure zip into GI_HOME.
#   Runs on the node that owns the GI install (node1 for cluster,
#   the sole node for Oracle Restart).
#------------------------------------------------------------------------------
# 中文说明：
# - 此脚本校验并解压 Grid Infrastructure 安装介质。
# - 仅翻译面向使用者的提示信息，保留命令、变量、路径与配置键原样。

. /vagrant/scripts/_common.sh
# 共享工具函数负责日志格式、参数校验与磁盘解析。
require_root
require_var GI_HOME
require_var GI_SOFTWARE

verify_installer_cksum "${GI_SOFTWARE}"

log_section "正在将 ${GI_SOFTWARE} 解压到 ${GI_HOME}"
mkdir -p "${GI_HOME}"
(
  cd "${GI_HOME}"
  unzip -oq "/vagrant/ORCL_software/${GI_SOFTWARE}"
)
chown -R grid:oinstall "${GI_HOME}"
log_success "Grid Infrastructure 已解压到 ${GI_HOME}"
