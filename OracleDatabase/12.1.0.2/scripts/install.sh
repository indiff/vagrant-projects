#!/bin/bash
#
# LICENSE UPL 1.0
#
# Copyright (c) 1982-2018 Oracle and/or its affiliates. All rights reserved.
# 
# Since: January, 2018
# Author: gerald.venzl@oracle.com
# Description: Installs Oracle database software
# 
# DO NOT ALTER OR REMOVE COPYRIGHT NOTICES OR THIS HEADER.
#

# Abort on any error
# 中文说明：
# 用于校验安装介质、准备系统依赖，并以静默方式安装或创建 Oracle 数据库。

set -e

echo 'INSTALLER: 已启动'

# 中文：先确认安装介质可用，再继续系统与数据库安装。
# verify that database installers are present and valid
echo 'INSTALLER: 正在校验数据库安装文件s'

case "$ORACLE_EDITION" in
  'EE')
    digest_file='db_installer-EE.sha256'
    installer_zips='linuxamd64_12102_database_?of2.zip'
    ;;
  'SE2')
    digest_file='db_installer-SE2.sha256'
    installer_zips='linuxamd64_12102_database_se2_?of2.zip'
    ;;
  *)
    echo "INSTALLER: ORACLE_EDITION ${ORACLE_EDITION} 无效，必须为 EE 或 SE2。正在退出。"
    exit 1
    ;;
esac

sha256sum --check /vagrant/"${digest_file}" || {
  cat << EOF

INSTALLER: 数据库安装文件缺失或无效。
           请销毁此 VM（vagrant destroy），然后
           请确认数据库安装文件s
           与 Vagrantfile 位于同一目录中，
           且其 SHA-256 摘要与
           ${digest_file} 文件中的值一致，
           然后再重新运行 vagrant up。

EOF
  exit 1
}

# get up to date
yum upgrade -y

echo 'INSTALLER: 系统已更新'

# fix locale warning
yum reinstall -y glibc-common
echo LANG=en_US.utf-8 >> /etc/environment
echo LC_ALL=en_US.utf-8 >> /etc/environment

echo 'INSTALLER: 区域设置已完成'

# set system time zone
sudo timedatectl set-timezone $SYSTEM_TIMEZONE
echo "INSTALLER: 系统时区已设置为 $SYSTEM_TIMEZONE"

# Install Oracle Database prereq and openssl packages
yum install -y oracle-rdbms-server-12cR1-preinstall openssl

echo 'INSTALLER: Oracle 预安装包和 openssl 已安装完成'

# create directories
mkdir -p $ORACLE_BASE
chown oracle:oinstall -R $ORACLE_BASE
mkdir -p /u01/app
ln -s $ORACLE_BASE /u01/app/oracle

echo 'INSTALLER: Oracle 目录已创建'

# set environment variables
echo "export ORACLE_BASE=$ORACLE_BASE" >> /home/oracle/.bashrc
echo "export ORACLE_HOME=$ORACLE_HOME" >> /home/oracle/.bashrc
echo "export ORACLE_SID=$ORACLE_SID" >> /home/oracle/.bashrc
echo "export PATH=\$PATH:\$ORACLE_HOME/bin" >> /home/oracle/.bashrc

echo 'INSTALLER: 环境变量已设置'

# Install Oracle

unzip /vagrant/"${installer_zips}" -d /tmp

cp /vagrant/ora-response/db_install.rsp.tmpl /tmp/db_install.rsp
sed -i -e "s|###ORACLE_BASE###|$ORACLE_BASE|g" /tmp/db_install.rsp
sed -i -e "s|###ORACLE_HOME###|$ORACLE_HOME|g" /tmp/db_install.rsp
sed -i -e "s|###ORACLE_EDITION###|$ORACLE_EDITION|g" /tmp/db_install.rsp
su -l oracle -c "yes | /tmp/database/runInstaller -silent -showProgress -ignorePrereq -waitforcompletion -responseFile /tmp/db_install.rsp"
$ORACLE_BASE/oraInventory/orainstRoot.sh
$ORACLE_HOME/root.sh
# some files in the installer zips are extracted without write permissions
chmod -R u+w /tmp/database
rm -rf /tmp/database
rm /tmp/db_install.rsp

echo 'INSTALLER: Oracle 软件已安装'

# create sqlnet.ora, listener.ora and tnsnames.ora
su -l oracle -c "mkdir -p $ORACLE_HOME/network/admin"
su -l oracle -c "echo 'NAME.DIRECTORY_PATH= (TNSNAMES, EZCONNECT, HOSTNAME)' > $ORACLE_HOME/network/admin/sqlnet.ora"

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
' > $ORACLE_HOME/network/admin/listener.ora"

su -l oracle -c "echo '$ORACLE_SID=localhost:$LISTENER_PORT/$ORACLE_SID' > $ORACLE_HOME/network/admin/tnsnames.ora"
su -l oracle -c "echo '$ORACLE_PDB= 
(DESCRIPTION = 
  (ADDRESS = (PROTOCOL = TCP)(HOST = 0.0.0.0)(PORT = $LISTENER_PORT))
  (CONNECT_DATA =
    (SERVER = DEDICATED)
    (SERVICE_NAME = $ORACLE_PDB)
  )
)' >> $ORACLE_HOME/network/admin/tnsnames.ora"

# Start LISTENER
su -l oracle -c "lsnrctl start"

echo 'INSTALLER: 监听器已创建'

# Create database

# Auto generate ORACLE PWD if not passed on
export ORACLE_PWD=${ORACLE_PWD:-"`openssl rand -base64 8`1"}

cp /vagrant/ora-response/dbca.rsp.tmpl /tmp/dbca.rsp
sed -i -e "s|###ORACLE_SID###|$ORACLE_SID|g" /tmp/dbca.rsp
sed -i -e "s|###ORACLE_PDB###|$ORACLE_PDB|g" /tmp/dbca.rsp
sed -i -e "s|###ORACLE_CHARACTERSET###|$ORACLE_CHARACTERSET|g" /tmp/dbca.rsp
sed -i -e "s|###ORACLE_PWD###|$ORACLE_PWD|g" /tmp/dbca.rsp
sed -i -e "s|###EM_EXPRESS_PORT###|$EM_EXPRESS_PORT|g" /tmp/dbca.rsp

# Create DB
su -l oracle -c "dbca -silent -createDatabase -responseFile /tmp/dbca.rsp"

# Post DB setup tasks
# 12.1.0.2 requires DBMS_XDB_CONFIG.SETHTTPSPORT for non-standard port to work
su -l oracle -c "sqlplus / as sysdba <<EOF
   ALTER PLUGGABLE DATABASE $ORACLE_PDB SAVE STATE;
   ALTER SYSTEM SET LOCAL_LISTENER = '(ADDRESS = (PROTOCOL = TCP)(HOST = 0.0.0.0)(PORT = $LISTENER_PORT))' SCOPE=BOTH;
   ALTER SYSTEM REGISTER;
   EXEC DBMS_XDB_CONFIG.SETHTTPSPORT ($EM_EXPRESS_PORT);
   exit;
EOF"

rm /tmp/dbca.rsp

echo 'INSTALLER: 数据库已创建'

sed -i -e "\$s|${ORACLE_SID}:${ORACLE_HOME}:N|${ORACLE_SID}:${ORACLE_HOME}:Y|" /etc/oratab
echo 'INSTALLER: Oratab 已配置'

# configure systemd to start oracle instance on startup
sudo cp /vagrant/scripts/oracle-rdbms.service /etc/systemd/system/
sudo sed -i -e "s|###ORACLE_HOME###|$ORACLE_HOME|g" /etc/systemd/system/oracle-rdbms.service
sudo systemctl daemon-reload
sudo systemctl enable oracle-rdbms
sudo systemctl start oracle-rdbms
echo "INSTALLER: 已创建并启用 oracle-rdbms systemd 服务"

sudo cp /vagrant/scripts/setPassword.sh /home/oracle/
sudo chown oracle:oinstall /home/oracle/setPassword.sh
sudo chmod u+x /home/oracle/setPassword.sh

echo "INSTALLER: setPassword.sh 文件已就绪";

# 中文：标准安装结束后，再按顺序执行用户自定义脚本。
# run user-defined post-setup scripts
echo 'INSTALLER: 正在运行用户自定义的安装后脚本'

for f in /vagrant/userscripts/*
  do
    case "${f,,}" in
      *.sh)
        echo "INSTALLER: 正在运行 $f"
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

echo "SYS、SYSTEM 和 PDBADMIN 的 ORACLE 密码：$ORACLE_PWD";

echo "INSTALLER: 安装完成，数据库已可用！";
