#!/usr/bin/env bash
#------------------------------------------------------------------------------
# LICENSE UPL 1.0
# Copyright (c) 1982-2026 Oracle and/or its affiliates. All rights reserved.
#
# 11_gi_root.sh
#   Run orainstRoot.sh + root.sh on both cluster nodes (or just locally for
#   Oracle Restart).
#------------------------------------------------------------------------------
. /vagrant/scripts/_common.sh
require_root
require_var ORA_INVENTORY
require_var GI_HOME
require_var ORESTART

log_section "Running orainstRoot.sh on local node"
sh "${ORA_INVENTORY}/orainstRoot.sh"

log_section "Running root.sh on local node"
sh "${GI_HOME}/root.sh"

if [[ "${ORESTART}" == "true" ]]; then
  log_section "Running roothas.pl (Oracle Restart)"
  "${GI_HOME}/perl/bin/perl" \
    -I "${GI_HOME}/perl/lib" -I "${GI_HOME}/crs/install" \
    "${GI_HOME}/crs/install/roothas.pl"
else
  require_var NODE2_HOSTNAME
  log_section "Running orainstRoot.sh + root.sh on ${NODE2_HOSTNAME}"
  ssh -o StrictHostKeyChecking=no "root@${NODE2_HOSTNAME}" "sh ${ORA_INVENTORY}/orainstRoot.sh"
  ssh -o StrictHostKeyChecking=no "root@${NODE2_HOSTNAME}" "sh ${GI_HOME}/root.sh"
fi
