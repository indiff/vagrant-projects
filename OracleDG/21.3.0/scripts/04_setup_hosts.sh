#!/usr/bin/env bash
#------------------------------------------------------------------------------
# LICENSE UPL 1.0
# Copyright (c) 1982-2026 Oracle and/or its affiliates. All rights reserved.
#
# 04_setup_hosts.sh
#   Writes /etc/hosts with public + private addresses for both nodes, and
#   a minimal /etc/resolv.conf. Re-runnable.
#------------------------------------------------------------------------------
. /vagrant/scripts/_common.sh
require_root
for v in NODE1_PUBLIC_IP NODE2_PUBLIC_IP NODE1_PRIV_IP NODE2_PRIV_IP \
         NODE1_HOSTNAME NODE2_HOSTNAME NODE1_FQ_HOSTNAME NODE2_FQ_HOSTNAME \
         NODE1_PRIVNAME NODE2_PRIVNAME NODE1_FQ_PRIVNAME NODE2_FQ_PRIVNAME \
         DOMAIN_NAME; do
  require_var "${v}"
done

log_section "Writing /etc/hosts"
cat > /etc/hosts <<EOF
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6

# Public host info
${NODE1_PUBLIC_IP}  ${NODE1_FQ_HOSTNAME}  ${NODE1_HOSTNAME}
${NODE2_PUBLIC_IP}  ${NODE2_FQ_HOSTNAME}  ${NODE2_HOSTNAME}

# Private host info
${NODE1_PRIV_IP}    ${NODE1_FQ_PRIVNAME}  ${NODE1_PRIVNAME}
${NODE2_PRIV_IP}    ${NODE2_FQ_PRIVNAME}  ${NODE2_PRIVNAME}
EOF

log_section "Writing /etc/resolv.conf"
cat > /etc/resolv.conf <<EOF
search ${DOMAIN_NAME}
EOF
