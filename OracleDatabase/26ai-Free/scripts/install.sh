#!/bin/bash
#
# Copyright (c) 2025 Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at
# https://oss.oracle.com/licenses/upl.
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

# get version to install
db_versions=/vagrant/db_versions.csv

if [[ ! -f "${db_versions}" || ! -r "${db_versions}" ]]; then
  echo "INSTALLER: 读取 ${db_versions} 出错，正在退出。"
  exit 1
fi

version_record=$(grep "^${DB_VERSION,,}," "${db_versions}") || {
  echo "INSTALLER: 在 ${db_versions} 中未找到版本 ${DB_VERSION}，正在退出。"
  exit 1
}

# shellcheck disable=SC2034
IFS=',' read -r version baseurl db_installer sha256 <<< "${version_record}"

# if the database installer exists, set parameter to keep it
# otherwise, download it
if [[ -f /vagrant/"${db_installer}" ]]; then
  KEEP_DB_INSTALLER='true'
else
  echo 'INSTALLER: 正在下载 Oracle AI Database 软件'
  curl -Ls -o /vagrant/"${db_installer}" "${baseurl}${db_installer}"
fi

# 中文：先确认安装介质可用，再继续系统与数据库安装。
# verify that database installer is valid
echo 'INSTALLER: 正在校验数据库安装文件'

if [[ $(sha256sum /vagrant/"${db_installer}" | awk '{print $1}') != "${sha256}" ]]; then
  cat << EOF

INSTALLER: 数据库安装文件无效。
           请销毁此 VM（vagrant destroy）并删除
           ${db_installer}
           然后再重新运行 vagrant up。

EOF
  exit 1
fi

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

# set environment variables
cat >> /home/oracle/.bashrc << EOF
export ORACLE_BASE=/opt/oracle
export ORACLE_HOME=/opt/oracle/product/26ai/dbhomeFree
export ORACLE_SID=FREE
export PATH=\$PATH:\$ORACLE_HOME/bin
EOF

echo 'INSTALLER: 环境变量已设置'

# Install Oracle
dnf -y install /vagrant/"${db_installer}"

if [[ "${KEEP_DB_INSTALLER,,}" == 'false' ]]; then
  rm -f /vagrant/"${db_installer}"
fi

echo 'INSTALLER: Oracle 软件已安装'

# Auto generate ORACLE PWD if not passed in
export ORACLE_PWD=${ORACLE_PWD:-"$(openssl rand -hex 8)1"}

# Create database
cfg_file='/etc/sysconfig/oracle-free-26ai.conf'
mv "${cfg_file}" "${cfg_file}".original
cp /vagrant/ora-response/oracle-free-26ai.conf.tmpl "${cfg_file}"
chmod g+w "${cfg_file}"

sed -i -e "s|###LISTENER_PORT###|$LISTENER_PORT|g" "${cfg_file}"
sed -i -e "s|###ORACLE_CHARACTERSET###|$ORACLE_CHARACTERSET|g" "${cfg_file}"
(echo "${ORACLE_PWD}"; echo "${ORACLE_PWD}") | /etc/init.d/oracle-free-26ai configure

chmod o+r /opt/oracle/product/26ai/dbhomeFree/network/admin/tnsnames.ora

# add tnsnames.ora entry for PDB
cat >> /opt/oracle/product/26ai/dbhomeFree/network/admin/tnsnames.ora << EOF
FREEPDB1 =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = localhost)(PORT = $LISTENER_PORT))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = FREEPDB1)
    )
  )
EOF

echo 'INSTALLER: 数据库已创建'

# configure systemd to start Oracle instance on startup
systemctl daemon-reload
systemctl enable oracle-free-26ai
systemctl start oracle-free-26ai
echo 'INSTALLER: 已创建并启用 oracle-free-26ai systemd 服务'

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
