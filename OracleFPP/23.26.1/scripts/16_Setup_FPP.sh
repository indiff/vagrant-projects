#!/usr/bin/env bash
#------------------------------------------------------------------------------
# LICENSE UPL 1.0
# Copyright (c) 1982-2026 Oracle and/or its affiliates. All rights reserved.
#
# 13_Setup_FPP.sh
#   Setup FPP server
#   Runs as root; drops to the grid user for asmcmd.
#------------------------------------------------------------------------------
# 中文说明：
# 用于配置 FPP 服务端相关资源，如 GNS、rhpserver 和仓库。

. /vagrant/scripts/_common.sh
require_root
for v in GI_HOME GI_VERSION GNS_IP HA_VIP SYS_PASSWORD; do
  require_var "${v}"
done

# 中文：这里改用 expect 驱动交互，避免 srvctl 直接从终端读取口令。
# srvctl reads the password from /dev/tty, bypassing stdin/heredoc.
# Drive the prompt with expect.
command -v expect >/dev/null || { log_error "未安装 expect（请执行 yum install -y expect）"; exit 1; }

log_section "正在将 DATA 磁盘组的 compatible.asm 设置为 ${GI_VERSION}"
su - grid -c "'${GI_HOME}/bin/asmcmd' setattr -G DATA compatible.asm '${GI_VERSION}'"

log_section "正在添加并启动 GNS（vip=${GNS_IP}）"
"${GI_HOME}/bin/srvctl" add gns -vip "${GNS_IP}"
"${GI_HOME}/bin/srvctl" start gns

#log_section "正在添加 RHP HAVIP（address=${HA_VIP}）"
#"${GI_HOME}/bin/srvctl" add havip -id rhphavip -address "${HA_VIP}"

# Replace the default rhpserver resource with one backed by /rhp_storage.
# The stop/remove may be a no-op on a fresh install (if the resource isn't
# registered or isn't running), so don't let them abort the ERR trap.
log_section "正在将 rhpserver 重新配置到 /rhp_storage（DATA）"
"${GI_HOME}/bin/srvctl" stop rhpserver   || true
"${GI_HOME}/bin/srvctl" remove rhpserver || true
expect <<EOF
set timeout 300
spawn ${GI_HOME}/bin/srvctl add rhpserver -storage /rhp_storage -diskgroup DATA -dbtype FPPDB -rhpsvip_address ${HA_VIP}
expect {
  -re "(?i)password:" { send -- "${SYS_PASSWORD}\r"; exp_continue }
  eof
}
catch wait result
exit [lindex \$result 3]
EOF

"${GI_HOME}/bin/srvctl" start rhpserver
"${GI_HOME}/bin/srvctl" status rhpserver
#----------------------------------------------------------
# EndOfFile
#----------------------------------------------------------
