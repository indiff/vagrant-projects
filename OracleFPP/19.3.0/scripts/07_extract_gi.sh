#!/usr/bin/env bash
#------------------------------------------------------------------------------
# LICENSE UPL 1.0
# Copyright (c) 1982-2026 Oracle and/or its affiliates. All rights reserved.
#
# 07_extract_gi.sh
#   Verify and extract the Grid Infrastructure zip into GI_HOME.
#   Runs on the node that owns the GI install (node1 for a two-node cluster,
#   the sole node for a single-node cluster).
#------------------------------------------------------------------------------
. /vagrant/scripts/_common.sh
require_root
require_var GI_HOME
require_var GI_SOFTWARE

verify_installer_cksum "${GI_SOFTWARE}"

log_section "Extracting ${GI_SOFTWARE} into ${GI_HOME}"
mkdir -p "${GI_HOME}"
(
  cd "${GI_HOME}"
  unzip -oq "/vagrant/ORCL_software/${GI_SOFTWARE}"
)
chown -R grid:oinstall "${GI_HOME}"
log_success "Grid Infrastructure extracted into ${GI_HOME}"
