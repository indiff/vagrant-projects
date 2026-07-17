#!/bin/bash
#
# LICENSE UPL 1.0
#
# Copyright (c) 1982-2018 Oracle and/or its affiliates. All rights reserved.
# 
# Since: July, 2018
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

# if the database installer exists, set parameter to keep it
# otherwise, download it
db_installer='oracle-database-xe-18c-1.0-1.x86_64.rpm'

if [[ -f /vagrant/"${db_installer}" ]]; then
  KEEP_DB_INSTALLER='true'
else
  echo 'INSTALLER: 正在下载 Oracle Database 软件'
  curl -Ls -o /vagrant/"${db_installer}" \
       https://download.oracle.com/otn-pub/otn_software/db-express/"${db_installer}"
fi

# 中文：先确认安装介质可用，再继续系统与数据库安装。
# verify that database installer is valid
echo 'INSTALLER: 正在校验数据库安装文件'

sha256sum --check /vagrant/db_installer.sha256 || {
  cat << EOF

INSTALLER: 数据库安装文件无效。
           请销毁此 VM（vagrant destroy）并删除
           ${db_installer}
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
# (preinstall is pulled automatically with 18c XE rpm, but it
#  doesn't create /home/oracle unless it's installed separately)
yum install -y oracle-database-preinstall-18c openssl

echo 'INSTALLER: Oracle 预安装包和 openssl 已安装完成'

# set environment variables
echo "export ORACLE_BASE=/opt/oracle" >> /home/oracle/.bashrc
echo "export ORACLE_HOME=/opt/oracle/product/18c/dbhomeXE" >> /home/oracle/.bashrc
echo "export ORACLE_SID=XE" >> /home/oracle/.bashrc
echo "export PATH=\$PATH:\$ORACLE_HOME/bin" >> /home/oracle/.bashrc

echo 'INSTALLER: 环境变量已设置'

# Install Oracle
yum -y localinstall /vagrant/"${db_installer}"

if [[ "${KEEP_DB_INSTALLER,,}" == 'false' ]]; then
  rm -f /vagrant/"${db_installer}"
fi

echo 'INSTALLER: Oracle 软件已安装'

# Auto generate ORACLE PWD if not passed on
export ORACLE_PWD=${ORACLE_PWD:-"`openssl rand -base64 8`1"}

# Create database
mv /etc/sysconfig/oracle-xe-18c.conf /etc/sysconfig/oracle-xe-18c.conf.original
cp /vagrant/ora-response/oracle-xe-18c.conf.tmpl /etc/sysconfig/oracle-xe-18c.conf
chmod g+w /etc/sysconfig/oracle-xe-18c.conf

sed -i -e "s|###LISTENER_PORT###|$LISTENER_PORT|g" /etc/sysconfig/oracle-xe-18c.conf
sed -i -e "s|###EM_EXPRESS_PORT###|$EM_EXPRESS_PORT|g" /etc/sysconfig/oracle-xe-18c.conf
sed -i -e "s|###ORACLE_CHARACTERSET###|$ORACLE_CHARACTERSET|g" /etc/sysconfig/oracle-xe-18c.conf
sed -i -e "s|###ORACLE_PWD###|$ORACLE_PWD|g" /etc/sysconfig/oracle-xe-18c.conf
su -l -c '/etc/init.d/oracle-xe-18c configure'

chmod o+r /opt/oracle/product/18c/dbhomeXE/network/admin/tnsnames.ora

# add tnsnames.ora entry for PDB
echo "XEPDB1 =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = localhost)(PORT = $LISTENER_PORT))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = XEPDB1)
    )
  )
" >> /opt/oracle/product/18c/dbhomeXE/network/admin/tnsnames.ora

echo 'INSTALLER: 数据库已创建'

# enable global port for EM Express
su -l oracle -c 'sqlplus / as sysdba <<EOF
   EXEC DBMS_XDB_CONFIG.SETGLOBALPORTENABLED (TRUE);
   exit
EOF'

echo 'INSTALLER: 已启用全局 EM Express 端口'

# configure systemd to start oracle instance on startup
sudo systemctl daemon-reload
sudo systemctl enable oracle-xe-18c
sudo systemctl start oracle-xe-18c
echo "INSTALLER: 已创建并启用 oracle-xe-18c systemd 服务"

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
