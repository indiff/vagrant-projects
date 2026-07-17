#!/usr/bin/env bash
#------------------------------------------------------------------------------
# LICENSE UPL 1.0
# Copyright (c) 1982-2026 Oracle and/or its affiliates. All rights reserved.
#
# 18_configure_root_ssh.sh
#   Idempotently set sshd's PermitRootLogin policy. Used by setup.sh to keep
#   password-based root SSH available only during RAC bootstrap, then switch
#   back to key-only once root SSH equivalence is established.
#
#   Args:
#     $1 = PermitRootLogin mode (yes | prohibit-password)
#------------------------------------------------------------------------------
# 中文说明：
# - 此脚本按引导阶段切换 root 的 SSH 登录策略。
# - 仅翻译面向使用者的提示信息，保留命令、变量、路径与配置键原样。

. /vagrant/scripts/_common.sh
# 共享工具函数负责日志格式、参数校验与磁盘解析。
require_root

if [[ $# -ne 1 ]]; then
  log_error "用法：$0 <yes|prohibit-password>"
  exit 1
fi

mode="$1"
sshd_config='/etc/ssh/sshd_config'

case "${mode}" in
  yes|prohibit-password) ;;
  *)
    log_error "不支持的 PermitRootLogin 模式 '${mode}'"
    exit 1
    ;;
esac

set_sshd_option() {
  local key="$1" value="$2"
  if grep -Eq "^[#[:space:]]*${key}[[:space:]]+" "${sshd_config}"; then
    sed -ri "s/^[#[:space:]]*${key}[[:space:]]+.*/${key} ${value}/" "${sshd_config}"
  else
    printf '\n%s %s\n' "${key}" "${value}" >> "${sshd_config}"
  fi
}

set_sshd_option PermitRootLogin "${mode}"

# Keep PasswordAuthentication in lock-step with PermitRootLogin. The bootstrap
# provisioner turned it on so sshUserSetup.sh could seed keys; once we're in
# prohibit-password mode the whole cluster is key-only and password SSH for
# oracle/grid would just be an unnecessary attack surface.
case "${mode}" in
  yes)               set_sshd_option PasswordAuthentication yes ;;
  prohibit-password) set_sshd_option PasswordAuthentication no  ;;
esac

/usr/sbin/sshd -t -f "${sshd_config}"
systemctl restart sshd

log_success "已配置 sshd：PermitRootLogin ${mode}"
