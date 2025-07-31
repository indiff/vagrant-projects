#!/bin/bash
#│▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒
#
# LICENSE UPL 1.0
#
# Copyright (c) 1982-2024 Oracle and/or its affiliates. All rights reserved.
#
#    NAME
#      10_gi_setup.sh
#
#    DESCRIPTION
#      GI Setup
#
#    NOTES
#       DO NOT ALTER OR REMOVE COPYRIGHT NOTICES OR THIS HEADER.
#
#    AUTHOR
#       Ruggero Citton - RAC Pack, Cloud Innovation and Solution Engineering Team
#
#    MODIFIED   (MM/DD/YY)
#    rcitton     03/30/20 - VBox libvirt & kvm support
#    rcitton     11/06/18 - Creation
#
#    REVISION
#    20240603 - $Revision: 2.0.2.1 $
#
#│▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒│
set -x
. /vagrant/config/setup.env

echo "ORESTART $ORESTART" 

if [ "${ORESTART}" == "false" ]
then
  sh ${ORA_INVENTORY}/orainstRoot.sh
  sleep 10
  echo "手动创建Data"
su - grid -c "sqlplus / as sysasm <<EOF
CREATE DISKGROUP DATA EXTERNAL REDUNDANCY
  DISK '/dev/ORCL_DISK1_p1','/dev/ORCL_DISK2_p1','/dev/ORCL_DISK3_p1','/dev/ORCL_DISK4_p1'
  ATTRIBUTE 'au_size'='4M';
EOF"
  sh ${GI_HOME}/root.sh
  sleep 10
  
  su - grid -c 'asmcmd lsdsk'
  ssh root@${NODE2_HOSTNAME} sh ${ORA_INVENTORY}/orainstRoot.sh
  sleep 10
  ssh root@${NODE2_HOSTNAME} sh ${GI_HOME}/root.sh
  sleep 10
  echo "请查看 ${NODE2_HOSTNAME} 服务器,执行 asmcmd lsdsk"
  sleep 30 
else
  sh ${ORA_INVENTORY}/orainstRoot.sh
  sh ${GI_HOME}/root.sh
  ${GI_HOME}/perl/bin/perl -I ${GI_HOME}/perl/lib -I ${GI_HOME}/crs/install ${GI_HOME}/crs/install/roothas.pl
fi

#----------------------------------------------------------
# EndOfFile
#----------------------------------------------------------
