#!/usr/bin/env bash
#------------------------------------------------------------------------------
# LICENSE UPL 1.0
# Copyright (c) 1982-2026 Oracle and/or its affiliates. All rights reserved.
#
# 03_setup_hosts.sh
#   Write /etc/hosts (public, VIP, private) and stand up a local dnsmasq that
#   resolves the SCAN name to all three SCAN IPs. Point /etc/resolv.conf at
#   127.0.0.1 so CVU / gethostbyname see SCAN resolve to 3 addresses (required
#   to satisfy PRVG-11372 on Grid Infrastructure post-checks).
#------------------------------------------------------------------------------
# 中文说明：
# 用于配置主机名解析与 dnsmasq，确保 SCAN 名称按预期解析。

. /vagrant/scripts/_common.sh
require_root
for v in NODE1_PUBLIC_IP NODE1_PRIV_IP NODE1_VIP_IP \
         NODE1_HOSTNAME NODE1_FQ_HOSTNAME \
         NODE1_PRIVNAME NODE1_FQ_PRIVNAME \
         NODE1_VIPNAME  NODE1_FQ_VIPNAME \
         SCAN_IP1 SCAN_IP2 SCAN_IP3 SCAN_NAME FQ_SCAN_NAME \
         DOMAIN_NAME; do
  require_var "${v}"
done

# 中文：将公网、私网与 VIP 统一写入 hosts，便于集群解析。
log_section "正在写入 /etc/hosts"
# SCAN is intentionally NOT written to /etc/hosts — dnsmasq serves it with
# all three A records so CVU sees a SCAN→3 IP mapping.
{
  cat <<EOF
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6

# Public host info
${NODE1_PUBLIC_IP}  ${NODE1_FQ_HOSTNAME}  ${NODE1_HOSTNAME}
${NODE2_PUBLIC_IP}  ${NODE2_FQ_HOSTNAME}  ${NODE2_HOSTNAME}
EOF

  cat <<EOF
# Private host info
${NODE1_PRIV_IP}    ${NODE1_FQ_PRIVNAME}  ${NODE1_PRIVNAME}
${NODE2_PRIV_IP}    ${NODE2_FQ_PRIVNAME}  ${NODE2_PRIVNAME}
EOF

  cat <<EOF
# Virtual host info
${NODE1_VIP_IP}     ${NODE1_FQ_VIPNAME}   ${NODE1_VIPNAME}
EOF

} > /etc/hosts

log_section "正在为 SCAN 轮询解析配置 dnsmasq"
install -d -m 0755 /etc/dnsmasq.d

# host-record produces both forward (A) and reverse (PTR) records. Listing
# the SCAN name three times yields three A records in one response — what
# CVU (PRVG-11372) counts to match the three SCAN VIP resources.
cat > /etc/dnsmasq.d/oracle-rac.conf <<EOF
# Managed by 03_setup_hosts.sh — do not edit by hand.
# Bind to loopback only; dnsmasq is *not* acting as a LAN resolver.
listen-address=127.0.0.1
bind-interfaces

# dnsmasq reads /etc/hosts by default; no upstream resolver needed in this lab.
no-resolv
domain=${DOMAIN_NAME}
expand-hosts

# Return three SCAN A records (and matching PTRs) — dnsmasq rotates the
# answer order, so clients get round-robin resolution across ${SCAN_IP1},
# ${SCAN_IP2}, ${SCAN_IP3}.
host-record=${FQ_SCAN_NAME},${SCAN_NAME},${SCAN_IP1}
host-record=${FQ_SCAN_NAME},${SCAN_NAME},${SCAN_IP2}
host-record=${FQ_SCAN_NAME},${SCAN_NAME},${SCAN_IP3}
EOF

log_section "正在启用 dnsmasq"
systemctl enable dnsmasq
systemctl restart dnsmasq

log_section "正在写入 /etc/resolv.conf"
# Prevent NetworkManager/DHCP from stomping the file on the next lease.
# Clearing the immutable bit is a no-op if it was never set; re-setting is
# idempotent across re-provisions.
chattr -i /etc/resolv.conf 2>/dev/null || true
cat > /etc/resolv.conf <<EOF
search ${DOMAIN_NAME}
nameserver 127.0.0.1
EOF
chattr +i /etc/resolv.conf 2>/dev/null || true

log_section "正在校验 SCAN 解析结果"
# Fail fast if dnsmasq isn't returning 3 A records — it's the whole point
# of this script, and CVU will complain downstream if it's wrong.
scan_count=$(getent ahostsv4 "${FQ_SCAN_NAME}" | awk '{print $1}' | sort -u | wc -l)
if (( scan_count != 3 )); then
  log_error "期望 SCAN ${FQ_SCAN_NAME} 解析出 3 个 IP，实际为 ${scan_count}"
  getent ahostsv4 "${FQ_SCAN_NAME}" || true
  exit 1
fi
log_success "SCAN ${FQ_SCAN_NAME} 已通过 dnsmasq 解析为 3 个 IP"
