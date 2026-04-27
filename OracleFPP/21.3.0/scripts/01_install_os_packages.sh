#!/usr/bin/env bash
#------------------------------------------------------------------------------
# LICENSE UPL 1.0
# Copyright (c) 1982-2026 Oracle and/or its affiliates. All rights reserved.
#
# 01_install_os_packages.sh
#   Installs base packages and the Oracle preinstall bundle for RAC 21c on OL8.
#------------------------------------------------------------------------------
. /vagrant/scripts/_common.sh
require_root

log_section "Installing base packages"
yum install -y expect tree unzip zip openssl dnsmasq parted

log_section "Installing oracle-database-preinstall-21c"
yum install -y oracle-database-preinstall-21c

log_section "Disabling firewalld"
systemctl stop    firewalld 2>/dev/null || true
systemctl disable firewalld 2>/dev/null || true
