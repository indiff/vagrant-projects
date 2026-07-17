#!/usr/bin/env bash
#------------------------------------------------------------------------------
# LICENSE UPL 1.0
# Copyright (c) 1982-2026 Oracle and/or its affiliates. All rights reserved.
#
# 08_setup_user_equ.sh
#   Secure wrapper around 08_setup_user_equ.expect. Passes the user password
#   via the RAC_USER_PASSWORD env var — so it never appears in 'ps' output.
#
#   Args:
#     $1 = username (root | grid | oracle)
#     $2 = password (plain text — from setup.env, never from argv on disk)
#     $3 = node1 hostname
#     $4 = node2 hostname
#------------------------------------------------------------------------------
# 中文说明：
# - 此脚本安全地包装 Expect 调用，并通过环境变量传递口令。
# - 仅翻译面向使用者的提示信息，保留命令、变量、路径与配置键原样。

. /vagrant/scripts/_common.sh
# 共享工具函数负责日志格式、参数校验与磁盘解析。
require_root
require_var GI_HOME

if [[ $# -ne 4 ]]; then
  log_error "用法：$0 <user> <password> <node1> <node2>"
  exit 1
fi

user="$1"
password="$2"
node1="$3"
node2="$4"
ssh_setup="${GI_HOME}/oui/prov/resources/scripts/sshUserSetup.sh"
expect_driver='/vagrant/scripts/08_setup_user_equ.expect'

if [[ ! -x "${ssh_setup}" ]]; then
  log_error "未找到 sshUserSetup.sh，或该文件不可执行：${ssh_setup}"
  exit 1
fi
if [[ ! -f "${expect_driver}" ]]; then
  log_error "expect driver not found: ${expect_driver}"
  exit 1
fi
if ! getent passwd "${user}" >/dev/null; then
  log_error "OS user '${user}' does not exist"
  exit 1
fi

log_info "正在为 '${user}' between ${node1} and ${node2}"

# Run Oracle's helper inside the target user's login shell so ~/.ssh resolves
# to the correct home directory. Preserve only the password env var to keep it
# out of argv and process listings. sudo is used instead of `runuser -l -w`
# because OL8's util-linux predates runuser's --whitelist-environment flag.
printf -v runuser_cmd 'expect -f %q %q %q %q %q' \
  "${expect_driver}" "${user}" "${node1}" "${node2}" "${ssh_setup}"

RAC_USER_PASSWORD="${password}" \
  sudo -u "${user}" -H --preserve-env=RAC_USER_PASSWORD -- \
  bash -lc "${runuser_cmd}"
