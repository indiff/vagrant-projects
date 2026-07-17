#!/usr/bin/env bash
#------------------------------------------------------------------------------
# LICENSE UPL 1.0
# Copyright (c) 1982-2026 Oracle and/or its affiliates. All rights reserved.
#
# 11_gi_root.sh
#   Run orainstRoot.sh + root.sh on both cluster nodes (or just locally for
#   a single-node cluster).
#------------------------------------------------------------------------------
# 中文说明：
# 用于执行 orainstRoot.sh 和 root.sh，完成 GI 的 root 阶段。

. /vagrant/scripts/_common.sh
require_root
require_var ORA_INVENTORY
require_var GI_HOME

log_section "正在在本地节点运行 orainstRoot.sh"
# 中文：root 脚本必须按顺序执行，避免 GI 安装状态不一致。
sh "${ORA_INVENTORY}/orainstRoot.sh"

log_section "正在在本地节点运行 root.sh"
sh "${GI_HOME}/root.sh"
