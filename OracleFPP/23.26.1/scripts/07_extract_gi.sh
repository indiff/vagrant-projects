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
# 用于校验并解压 Grid Infrastructure 安装介质。

. /vagrant/scripts/_common.sh
require_root
require_var GI_HOME
require_var GI_SOFTWARE

# 中文：解压前先校验介质，避免带着损坏文件继续执行。
verify_installer_cksum "${GI_SOFTWARE}"

log_section "正在将 ${GI_SOFTWARE} 解压到 ${GI_HOME}"
mkdir -p "${GI_HOME}"
(
  cd "${GI_HOME}"
  unzip -oq "/vagrant/ORCL_software/${GI_SOFTWARE}"
)

patch_ssh_user_setup_bits() {
  local script_path="$1"

  [[ -f "${script_path}" ]] || return 0

  # Oracle still ships sshUserSetup.sh with 1024-bit RSA keys, but OL9's
  # system crypto policy requires RSA keys to be at least 2048 bits.
  if grep -qx 'BITS=1024' "${script_path}"; then
    sed -ri 's/^BITS=1024$/BITS=2048/' "${script_path}"
    log_info "已修补 ${script_path}，使其生成 2048 位 RSA 密钥"
  elif grep -qx 'BITS=2048' "${script_path}"; then
    log_info "${script_path} 已经生成 2048 位 RSA 密钥"
  else
    log_error "${script_path} 中的 sshUserSetup.sh 密钥位数配置不符合预期"
    exit 1
  fi
}

patch_ssh_user_setup_bits "${GI_HOME}/oui/prov/resources/scripts/sshUserSetup.sh"
patch_ssh_user_setup_bits "${GI_HOME}/deinstall/sshUserSetup.sh"

chown -R grid:oinstall "${GI_HOME}"
log_success "已将 Grid Infrastructure 解压到 ${GI_HOME}"
