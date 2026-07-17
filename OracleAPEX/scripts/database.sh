#!/bin/bash
#
# LICENSE UPL 1.0
#
# Copyright © 1982-2019 Oracle and/or its affiliates. All rights reserved.
# Licensed under the Universal Permissive License v 1.0 as shown at http://oss.oracle.com/licenses/upl.
#
#    NAME
#      database.sh
#
#    DESCRIPTION
#      Install and Configure Oracle Database XE 18.4
#
#    NOTES
#       DO NOT ALTER OR REMOVE COPYRIGHT NOTICES OR THIS HEADER.
#
#    AUTHOR
#       Simon Coter
#
#    MODIFIED   (MM/DD/YY)
#    scoter     03/19/19 - Creation
#

# 中文说明：
# - 安装并初始化 Oracle Database XE。
# - 准备响应文件、创建数据库并启用常用网络与 systemd 配置。

# set environment variables
# 中文：先写入 Oracle 环境变量，供后续安装和登录脚本复用。
echo "export ORACLE_BASE=/opt/oracle" >> /home/oracle/.bashrc && \
echo "export ORACLE_HOME=/opt/oracle/product/18c/dbhomeXE" >> /home/oracle/.bashrc && \
echo "export ORACLE_SID=XE" >> /home/oracle/.bashrc && \
echo "export PATH=\$PATH:\$ORACLE_HOME/bin" >> /home/oracle/.bashrc

timedatectl set-timezone "$SYSTEM_TIMEZONE"
echo 'INSTALLER：时区已更新'

echo 'INSTALLER：环境变量已设置'

echo 'INSTALLER：Oracle Database 安装已开始'

# Install Oracle
yum -y localinstall /vagrant/oracle-database-xe-18c-*.x86_64.rpm

echo 'INSTALLER：Oracle 软件已安装'

# Auto generate ORACLE PWD if not passed on
export ORACLE_PWD=${ORACLE_PWD:-"`openssl rand -base64 8`1"}

# Create database
# 中文：基于模板响应文件写入字符集与口令后创建数据库。
mv /etc/sysconfig/oracle-xe-18c.conf /etc/sysconfig/oracle-xe-18c.conf.original && \
cp /vagrant/ora-response/oracle-xe-18c.conf.tmpl /etc/sysconfig/oracle-xe-18c.conf && \
chmod g+w /etc/sysconfig/oracle-xe-18c.conf && \
sed -i -e "s|###ORACLE_CHARACTERSET###|$ORACLE_CHARACTERSET|g" /etc/sysconfig/oracle-xe-18c.conf && \
sed -i -e "s|###ORACLE_PWD###|$ORACLE_PWD|g" /etc/sysconfig/oracle-xe-18c.conf

# required for database creation
. /home/oracle/.bashrc
su - oracle -c "mkdir -p $ORACLE_BASE/admin"

# start listener and database configuration
/etc/init.d/oracle-xe-18c configure

echo 'INSTALLER：数据库已创建'

# add tns entry for XEPDB1
chmod o+r /opt/oracle/product/18c/dbhomeXE/network/admin/tnsnames.ora

# add tnsnames.ora entry for PDB
echo 'XEPDB1 =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = localhost)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = XEPDB1)
    )
  )
' >> /opt/oracle/product/18c/dbhomeXE/network/admin/tnsnames.ora

echo 'INSTALLER：TNS 条目已添加'

# configure systemd to start oracle instance on startup
# 中文：把数据库实例纳入 systemd，便于开机自动启动。
systemctl daemon-reload
systemctl enable oracle-xe-18c
systemctl restart oracle-xe-18c
echo "INSTALLER：已创建并启用 oracle-xe-18c systemd 服务"

# enable global port for EM Express
su -l oracle -c 'sqlplus / as sysdba <<EOF
   EXEC DBMS_XDB_CONFIG.SETGLOBALPORTENABLED (TRUE);
   exit
EOF'

echo 'INSTALLER：已启用全局 EM Express 端口'

echo $ORACLE_PWD > /vagrant/apex-pwd

echo "SYS、SYSTEM 和 PDBADMIN 的 ORACLE 密码：$ORACLE_PWD";

echo "INSTALLER：安装完成，数据库已可使用！";
