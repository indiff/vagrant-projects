#!/bin/bash
#│▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒
#
# LICENSE UPL 1.0
#
# Copyright (c) 2018-2024 Oracle and/or its affiliates. All rights reserved.
#
#    NAME
#      06_setup_users.sh
#
#    DESCRIPTION
#      Setup oracle & grid users
#
#    NOTES
#       DO NOT ALTER OR REMOVE COPYRIGHT NOTICES OR THIS HEADER.
#
#    AUTHOR
#       Ruggero Citton - RAC Pack, Cloud Innovation and Solution Engineering Team
#
#    MODIFIED   (MM/DD/YY)
#    rcitton     11/18/24 - ORestart fix
#    rcitton     03/30/20 - VBox libvirt & kvm support
#    rcitton     11/06/18 - Creation
#
#    REVISION
#    20241118 - $Revision: 2.0.2.2 $
#
#│▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒│
. /vagrant/config/setup.env

echo "-----------------------------------------------------------------"
echo -e "${INFO}`date +%F' '%T`: Setup oracle and grid user"
echo "-----------------------------------------------------------------"
userdel -fr oracle
groupdel oinstall
groupdel dba
groupdel backupdba
groupdel dgdba
groupdel kmdba
groupdel racdba
groupadd -g 1001 oinstall
groupadd -g 1002 dbaoper
groupadd -g 1003 dba
groupadd -g 1004 asmadmin
groupadd -g 1005 asmoper
groupadd -g 1006 asmdba
groupadd -g 1007 backupdba
groupadd -g 1008 dgdba
groupadd -g 1009 kmdba
groupadd -g 1010 racdba
useradd oracle -d /home/oracle -m -p $(echo "oracle" | openssl passwd -1 -stdin) -g 1001 -G 1002,1003,1006,1007,1008,1009,1010
useradd grid   -d /home/grid   -m -p $(echo "oracle" | openssl passwd -1 -stdin) -g 1001 -G 1002,1003,1004,1005,1006

echo "-----------------------------------------------------------------"
echo -e "${INFO}`date +%F' '%T`: Set oracle and grid limits"
echo "-----------------------------------------------------------------"
cat << EOL >> /etc/security/limits.conf
# Grid user
grid soft nofile 131072
grid hard nofile 131072
grid soft nproc 131072
grid hard nproc 131072
grid soft core unlimited
grid hard core unlimited
grid soft memlock 98728941
grid hard memlock 98728941
grid soft stack 10240
grid hard stack 32768
# Oracle user
oracle soft nofile 131072
oracle hard nofile 131072
oracle soft nproc 131072
oracle hard nproc 131072
oracle soft core unlimited
oracle hard core unlimited
oracle soft memlock 98728941
oracle hard memlock 98728941
oracle soft stack 10240
oracle hard stack 32768
EOL

echo "-----------------------------------------------------------------"
echo -e "${INFO}`date +%F' '%T`: Create GI_HOME and DB_HOME directories"
echo "-----------------------------------------------------------------"
mkdir -p ${GRID_BASE}
mkdir -p ${DB_BASE}
mkdir -p ${GI_HOME}
mkdir -p ${DB_HOME}
chown -R grid:oinstall /u01
chown -R grid:oinstall ${GRID_BASE}
chown -R grid:oinstall ${GI_HOME}
chown -R oracle:oinstall ${DB_BASE}
chown -R oracle:oinstall ${DB_HOME}
chmod -R ug+rw /u01




# 获取物理内存总字节数
mem_total=$(awk '/MemTotal/ {print $2}' /proc/meminfo) # 单位：KB
mem_bytes=$((mem_total * 1024))

# shmmax 设为物理内存一半
shmmax=$((mem_bytes / 2))

# shmall = shmmax / 页面大小（通常为4096字节）
pagesize=$(getconf PAGE_SIZE)
shmall=$((shmmax / pagesize))

echo "kernel.shmmax = $shmmax"
echo "kernel.shmall = $shmall"


# 物理内存为 8GB，kernel.shmmax 可设为 4GB（4294967296）或更大
cat > /etc/sysctl.conf <<EOF
kernel.shmall = $shmall
kernel.shmmax = $shmmax
kernel.shmmni = 4096
kernel.sem = 250 32000 100 128
fs.file-max = 6815744
fs.aio-max-nr = 1048576
net.ipv4.ip_local_port_range = 9000 65500
net.core.rmem_default=262144
net.core.rmem_max=4194304
net.core.wmem_default=262144
net.core.wmem_max=1048576
EOF

echo "-----------------------------------------------------------------"
echo -e "${INFO}`date +%F' '%T`: Set user env"
echo "-----------------------------------------------------------------"
if [ `hostname` == ${NODE1_HOSTNAME} ]; then
  if [ ${ORESTART} == "false" ]; then
    cat >> /home/grid/.bash_profile << EOF
export ORACLE_HOME=${GI_HOME}
export PATH=\$ORACLE_HOME/bin:$PATH
export ORACLE_SID=+ASM1
EOF
    cat >> /home/oracle/.bash_profile << EOF
export ORACLE_HOME=${DB_HOME}
export PATH=\$ORACLE_HOME/bin:$PATH
export ORACLE_SID=${DB_NAME}1
EOF
  else
    cat >> /home/grid/.bash_profile << EOF
export ORACLE_HOME=${GI_HOME}
export PATH=\$ORACLE_HOME/bin:$PATH
export ORACLE_SID=+ASM
EOF
    cat >> /home/oracle/.bash_profile << EOF
export ORACLE_HOME=${DB_HOME}
export PATH=\$ORACLE_HOME/bin:$PATH
export ORACLE_SID=${DB_NAME}
EOF
  fi
fi

if [ `hostname` == ${NODE2_HOSTNAME} ]; then
  if [ ${ORESTART} == "false" ]; then
    cat >> /home/grid/.bash_profile << EOF
export ORACLE_HOME=${GI_HOME}
export PATH=\$ORACLE_HOME/bin:$PATH
export ORACLE_SID=+ASM2
EOF
    cat >> /home/oracle/.bash_profile << EOF
export ORACLE_HOME=${DB_HOME}
export PATH=\$ORACLE_HOME/bin:$PATH
export ORACLE_SID=${DB_NAME}2
EOF
  else
    cat >> /home/grid/.bash_profile << EOF
export ORACLE_HOME=${GI_HOME}
export PATH=\$ORACLE_HOME/bin:$PATH
export ORACLE_SID=+ASM
EOF
    cat >> /home/oracle/.bash_profile << EOF
export ORACLE_HOME=${DB_HOME}
export PATH=\$ORACLE_HOME/bin:$PATH
export ORACLE_SID=${DB_NAME}
EOF
  fi
fi

## root用户可以直接使用crsctl命令
cat >> /etc/profile <<EOF
export PATH=${GI_HOME}/bin:$PATH
alias cdt='cd ${GI_HOME}/diag/asm/+asm/+ASM*/trace'
alias cdct='cd ${GI_HOME}/diag/crs/`hostname`/crs/trace'
alias csr='crsctl status res -t'
alias csi='crsctl status res -t -init'
EOF


#----------------------------------------------------------
# EndOfFile
#----------------------------------------------------------

