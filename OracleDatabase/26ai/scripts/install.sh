#!/bin/bash
#
# LICENSE UPL 1.0
#
# Copyright (c) 2026 Oracle and/or its affiliates. All rights reserved.
#
# Since: July, 2018
# Author: gerald.venzl@oracle.com
# Description: Installs Oracle AI Database software
#
# DO NOT ALTER OR REMOVE COPYRIGHT NOTICES OR THIS HEADER.
#

# Abort on any error
# 中文说明：
# 用于校验安装介质、准备系统依赖，并以静默方式安装或创建 Oracle 数据库。

set -Eeuo pipefail

echo 'INSTALLER: 已启动'

# 中文：先确认安装介质可用，再继续系统与数据库安装。
# verify that database installer is present and valid
echo 'INSTALLER: 正在校验数据库安装文件'

db_installer=/vagrant/LINUX.X64_2326100_db_home.zip

[[ $(cksum "$db_installer") == $(< /vagrant/db_installer.cksum) ]] || {
  cat << EOF

INSTALLER: 数据库安装文件缺失或无效。
           请销毁此 VM（vagrant destroy），然后
           请确认数据库安装文件
           与 Vagrantfile 位于同一目录中，
           且其校验和与文件大小与
           db_installer.cksum 文件中的值一致，
           然后再重新运行 vagrant up。

EOF
  exit 1
}

# get up to date
dnf upgrade -y

echo 'INSTALLER: 系统已更新'

# fix locale warning
dnf reinstall -y glibc-common
echo 'LANG=en_US.utf-8' >> /etc/environment
echo 'LC_ALL=en_US.utf-8' >> /etc/environment

echo 'INSTALLER: 区域设置已完成'

# set system time zone
timedatectl set-timezone "$SYSTEM_TIMEZONE"
echo "INSTALLER: 系统时区已设置为 $SYSTEM_TIMEZONE"

# Install Oracle AI Database preinstall and openssl packages
dnf install -y oracle-ai-database-preinstall-26ai openssl

echo 'INSTALLER: Oracle 预安装包和 openssl 已安装完成'

# create directories
mkdir -p "$ORACLE_HOME"
mkdir -p /u01/app
ln -s "$ORACLE_BASE" /u01/app/oracle
inventory_location=$(realpath "$ORACLE_BASE"/../oraInventory)
mkdir -p "$inventory_location"

echo 'INSTALLER: Oracle 目录已创建'

# set environment variables
# shellcheck disable=SC2153
cat >> /home/oracle/.bashrc << EOF
export ORACLE_BASE=$ORACLE_BASE
export ORACLE_HOME=$ORACLE_HOME
export ORACLE_SID=$ORACLE_SID
export PATH=\$PATH:\$ORACLE_HOME/bin
EOF

echo 'INSTALLER: 环境变量已设置'

# Install Oracle
unzip "$db_installer" -d "$ORACLE_HOME"/
cp /vagrant/ora-response/db_install.rsp.tmpl /tmp/db_install.rsp
sed -i -e "s|###INVENTORY_LOCATION###|$inventory_location|g" /tmp/db_install.rsp
sed -i -e "s|###ORACLE_BASE###|$ORACLE_BASE|g" /tmp/db_install.rsp
sed -i -e "s|###ORACLE_HOME###|$ORACLE_HOME|g" /tmp/db_install.rsp
chown oracle:oinstall -R "$ORACLE_BASE" "$inventory_location"

# runInstaller should return 6 (successful with warnings) when prereqs are ignored
su -l oracle -c "yes | $ORACLE_HOME/runInstaller -silent -ignorePrereqFailure -waitforcompletion -responseFile /tmp/db_install.rsp" || {
  ret=$?
  if [[ $ret -ne 6 ]]; then
    echo 'Oracle AI Database 安装程序异常退出！'
    exit $ret;
  fi;
}

"$inventory_location"/orainstRoot.sh
"$ORACLE_HOME"/root.sh
rm /tmp/db_install.rsp

echo 'INSTALLER: Oracle 软件已安装'

# create sqlnet.ora, listener.ora and tnsnames.ora
if [[ "${RO_ORACLE_HOME,,}" == 'false' ]]; then
  network_admin_dir="$ORACLE_HOME"/network/admin
else
  su -l oracle -c 'roohctl -enable'
  network_admin_dir=$("$ORACLE_HOME"/bin/orabasehome)/network/admin
fi

su -l oracle -c "mkdir -p $network_admin_dir"
su -l oracle -c "echo 'NAME.DIRECTORY_PATH= (TNSNAMES, EZCONNECT, HOSTNAME)' > $network_admin_dir/sqlnet.ora"

# Listener.ora
su -l oracle -c "echo 'LISTENER =
(DESCRIPTION_LIST =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = IPC)(KEY = EXTPROC1))
    (ADDRESS = (PROTOCOL = TCP)(HOST = 0.0.0.0)(PORT = $LISTENER_PORT))
  )
)

DEDICATED_THROUGH_BROKER_LISTENER=ON
DIAG_ADR_ENABLED = off
' > $network_admin_dir/listener.ora"

su -l oracle -c "echo '$ORACLE_SID=localhost:$LISTENER_PORT/$ORACLE_SID' > $network_admin_dir/tnsnames.ora"
# shellcheck disable=SC2153
su -l oracle -c "echo '$ORACLE_PDB=
(DESCRIPTION =
  (ADDRESS = (PROTOCOL = TCP)(HOST = 0.0.0.0)(PORT = $LISTENER_PORT))
  (CONNECT_DATA =
    (SERVER = DEDICATED)
    (SERVICE_NAME = $ORACLE_PDB)
  )
)' >> $network_admin_dir/tnsnames.ora"

# Start LISTENER
su -l oracle -c 'lsnrctl start'

echo 'INSTALLER: 监听器已创建'

# Create database

# Auto generate ORACLE PWD if not passed in
export ORACLE_PWD=${ORACLE_PWD:-"$(openssl rand -base64 8)1"}

cp /vagrant/ora-response/dbca.rsp.tmpl /tmp/dbca.rsp
sed -i -e "s|###ORACLE_SID###|$ORACLE_SID|g" /tmp/dbca.rsp
sed -i -e "s|###ORACLE_PDB###|$ORACLE_PDB|g" /tmp/dbca.rsp
sed -i -e "s|###ORACLE_CHARACTERSET###|$ORACLE_CHARACTERSET|g" /tmp/dbca.rsp
sed -i -e "s|###ORACLE_PWD###|$ORACLE_PWD|g" /tmp/dbca.rsp

# Create DB
su -l oracle -c 'dbca -silent -createDatabase -responseFile /tmp/dbca.rsp'

# Post DB setup tasks
su -l oracle -c "sqlplus / as sysdba << EOF
   ALTER PLUGGABLE DATABASE $ORACLE_PDB SAVE STATE;
   ALTER SYSTEM SET LOCAL_LISTENER = '(ADDRESS = (PROTOCOL = TCP)(HOST = 0.0.0.0)(PORT = $LISTENER_PORT))' SCOPE=BOTH;
   ALTER SYSTEM REGISTER;
   exit
EOF"

rm /tmp/dbca.rsp

echo 'INSTALLER: 数据库已创建'

sed -i -e "\$s|${ORACLE_SID}:${ORACLE_HOME}:N|${ORACLE_SID}:${ORACLE_HOME}:Y|" /etc/oratab
echo 'INSTALLER: Oratab 已配置'

# configure systemd to start Oracle instance on startup
cp /vagrant/scripts/oracle-rdbms.service /etc/systemd/system/
sed -i -e "s|###ORACLE_HOME###|$ORACLE_HOME|g" /etc/systemd/system/oracle-rdbms.service
systemctl daemon-reload
systemctl enable oracle-rdbms
systemctl start oracle-rdbms
echo "INSTALLER: 已创建并启用 oracle-rdbms systemd 服务"

cp /vagrant/scripts/setPassword.sh /home/oracle/
chown oracle:oinstall /home/oracle/setPassword.sh
chmod u=rwx,go=r /home/oracle/setPassword.sh

echo 'INSTALLER: setPassword.sh 文件已就绪'

# 中文：标准安装结束后，再按顺序执行用户自定义脚本。
# run user-defined post-setup scripts
echo 'INSTALLER: 正在运行用户自定义的安装后脚本'

for f in /vagrant/userscripts/*
  do
    case "${f,,}" in
      *.sh)
        echo "INSTALLER: 正在运行 $f"
        # shellcheck disable=SC1090
        . "$f"
        echo "INSTALLER: 已完成 $f"
        ;;
      *.sql)
        echo "INSTALLER: 正在运行 $f"
        su -l oracle -c "echo 'exit' | sqlplus -s / as sysdba @\"$f\""
        echo "INSTALLER: 已完成 $f"
        ;;
      /vagrant/userscripts/put_custom_scripts_here.txt)
        :
        ;;
      *)
        echo "INSTALLER: 已忽略 $f"
        ;;
    esac
  done

echo 'INSTALLER: 已完成用户自定义的安装后脚本'

echo "SYS、SYSTEM 和 PDBADMIN 的 ORACLE 密码：$ORACLE_PWD"

echo 'INSTALLER: 安装完成，数据库已可用！'
