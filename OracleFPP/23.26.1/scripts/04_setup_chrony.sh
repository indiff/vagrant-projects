#!/usr/bin/env bash
#------------------------------------------------------------------------------
# LICENSE UPL 1.0
# Copyright (c) 1982-2026 Oracle and/or its affiliates. All rights reserved.
#
# 04_setup_chrony.sh
#   Disable chronyd (and any stray ntpd) so Oracle's Cluster Time
#   Synchronization Service (CTSS) runs in *active* mode — the only
#   configuration that satisfies CVU PRVG-13606 on an isolated lab where
#   no external NTP peer is reachable.
#
#   Why not 'local stratum 10'?
#     chronyc tracking reports Leap=Normal with that, but the 19.3.0 CVU
#     post-crsinst check inspects the Reference ID and rejects local
#     refclocks — PRVG-13606 still fires.
#
#   Why not node-to-node peering?
#     With both nodes self-stratum 10, chrony's source selector won't prefer
#     the peer over its own local clock, so node1 at least keeps reporting
#     a local refid and CVU fails on that node.
#
#   CTSS active mode is what Oracle's own RAC Vagrant projects use, and is
#   documented as the intended path when no external time source exists.
#
#   CRITICAL: this must run BEFORE GI root.sh / executeConfigTools. CTSS's
#   mode (observer vs active) is latched at CRS startup based on whether a
#   time daemon is active at that moment. If chronyd is already running when
#   CRS starts, CTSS registers as observer and this fix won't help without
#   a CRS restart.
#------------------------------------------------------------------------------
# 中文说明：
# 用于停用系统时间服务，让 CTSS 以 active 模式接管时间同步。

. /vagrant/scripts/_common.sh
require_root

log_section "正在禁用 chronyd（改由 CTSS 以 active 模式运行）"
systemctl stop    chronyd 2>/dev/null || true
systemctl disable chronyd 2>/dev/null || true

log_section "如果存在 ntpd，则一并禁用（双重保险）"
systemctl stop    ntpd 2>/dev/null || true
systemctl disable ntpd 2>/dev/null || true

log_section "正在迁移 /etc/chrony.conf 以便保留原始配置"
# Rename rather than delete so an operator can still see the original if
# they ever want to re-enable chrony.
# 中文：保留原始 chrony 配置，便于后续人工回滚。
if [[ -f /etc/chrony.conf && ! -f /etc/chrony.conf.rac-backup ]]; then
  mv /etc/chrony.conf /etc/chrony.conf.rac-backup
fi
# Also rip up any previous attempts (local stratum 10, etc.) left over in
# an already-provisioned VM.
rm -f /etc/chrony.conf

log_section "正在清理遗留的 chrony 运行时文件"
# Belt-and-suspenders: make sure CTSS doesn't see a lingering pid/socket
# and decide to register as observer.
rm -f /var/run/chrony/chronyd.pid   /var/run/chronyd.pid \
      /var/run/chrony/chronyd.sock  /var/run/chronyd.sock \
      /var/run/ntpd.pid 2>/dev/null || true

log_section "正在确认没有活动的时间同步守护进程"
for svc in chronyd ntpd ntp; do
  if systemctl is-active --quiet "${svc}"; then
    log_error "${svc} 仍处于活动状态，CTSS 将以 observer 而非 active 模式注册"
    exit 1
  fi
done
log_success "当前没有活动的时间同步守护进程；CTSS 会在 CRS 启动时进入 active 模式"
