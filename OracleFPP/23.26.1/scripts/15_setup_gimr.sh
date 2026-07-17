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
require_var GI_HOME
require_var SYS_PASSWORD

if [[ "${DB_MAJOR}" -lt 21 ]]; then
  log_info "DB_MAJOR=${DB_MAJOR} < 21；GIMR 由 gridSetup.sh 管理，无需额外操作"
  exit 0
fi

# 中文：21c+ 需要单独创建仓库或 GIMR 相关数据库组件。
repos_script="${GI_HOME}/crs/install/reposScript.sh"
if [[ ! -x "${repos_script}" ]]; then
  log_error "未找到 reposScript.sh，或其不可执行：${repos_script}"
  exit 1
fi

log_section "正在创建 FPP 仓库（reposScript.sh -mode=Install）"
# reposScript.sh prompts once on stdin for the FPPREPOS Database System Password.
"${repos_script}" \
  -db_home="${DB_HOME}/" \
  -mode="Install" \
  -diskgroup=+DATA <<EOF
${SYS_PASSWORD}
EOF
log_success "FPP 仓库已创建"
