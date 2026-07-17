#!/usr/bin/env bash
#------------------------------------------------------------------------------
# LICENSE UPL 1.0
# Copyright (c) 1982-2026 Oracle and/or its affiliates. All rights reserved.
#
# 20_setup_gimr.sh
#   Create the Grid Infrastructure Management Repository (GIMR) container
#   using mgmtca from the RDBMS home. Only used on 21c+ where GIMR is a
#   separate DB install; 19c configures GIMR inline via gridSetup.sh.
#   Runs on node1 as grid.
#------------------------------------------------------------------------------
# 中文说明：
# 用于在 21c+ 环境中创建 GIMR 或 FPP 仓库所需的数据库组件。

. /vagrant/scripts/_common.sh
require_user grid
require_var DB_HOME
require_var DB_MAJOR

if [[ "${DB_MAJOR}" -lt 21 ]]; then
  log_info "DB_MAJOR=${DB_MAJOR} < 21；GIMR 由 gridSetup.sh 管理，无需额外操作"
  exit 0
fi

log_section "正在创建 GIMR 容器（mgmtca）"
"${DB_HOME}/bin/mgmtca" createGIMRContainer -storageDiskLocation +DATA
log_success "GIMR 容器已创建"
