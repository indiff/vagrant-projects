#!/bin/bash
#│▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒
#
# Copyright (c) 2024 Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at
# https://oss.oracle.com/licenses/upl.
#
# Since: August, 2024
# Author: ruggero.citton@oracle.com
# Description: Setup the environment
#
# DO NOT ALTER OR REMOVE COPYRIGHT NOTICES OR THIS HEADER.
#
#│▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒│

# Abort on any error
# 中文说明：
# - 此脚本串联 GDD 环境初始化流程，并在最后执行用户自定义后置脚本。
# - 仅翻译面向使用者的提示信息，保留命令、变量、路径与配置键原样。

set -Eeuo pipefail

# ---------------------------------------------------------------------
# Functions
# ---------------------------------------------------------------------
# 用户脚本在主流程末尾执行，便于追加自定义收尾动作。
run_user_scripts() {
  # run user-defined post-setup scripts
  echo "-----------------------------------------------------------------"
  echo -e "${INFO}`date +%F' '%T`: 正在运行用户自定义的后置脚本"
  echo "-----------------------------------------------------------------"
  for f in /vagrant/userscripts/*
    do
      case "${f,,}" in
        *.sh)
          echo -e "${INFO}`date +%F' '%T`: 正在运行 $f"
          . "$f"
          echo -e "${INFO}`date +%F' '%T`: 已完成 $f"
          ;;
        *.sql)
          echo -e "${INFO}`date +%F' '%T`: 正在运行 $f"
          su -l oracle -c "echo 'exit' | sqlplus -s / as sysdba @\"$f\""
          echo -e "${INFO}`date +%F' '%T`: 已完成 $f"
          ;;
        /vagrant/userscripts/put_custom_scripts_here.txt)
          :
          ;;
        *)
          echo -e "${INFO}`date +%F' '%T`: 忽略 $f"
          ;;
      esac
    done
}

# ---------------------------------------------------------------------
# MAIN
# ---------------------------------------------------------------------

# build the setup.env
echo "-----------------------------------------------------------------"
echo -e "生成 setup.env"
echo "-----------------------------------------------------------------"
export INFO='\033[0;34m信息：\033[0m'
export ERROR='\033[1;31m错误：\033[0m'
export SUCCESS='\033[1;32m成功：\033[0m'


# 生成 setup.env，供后续子脚本重复加载。
cat <<EOL > /vagrant/config/setup.env
#----------------------------------------------------------
# Env Variables
#----------------------------------------------------------
export PREFIX_NAME=$PREFIX_NAME
#----------------------------------------------------------
#----------------------------------------------------------
export SHARDING_SECRET=$SHARDING_SECRET
#----------------------------------------------------------
#----------------------------------------------------------
export PODMAN_REGISTRY_URI=$PODMAN_REGISTRY_URI
export PODMAN_REGISTRY_USER=$PODMAN_REGISTRY_USER
export PODMAN_REGISTRY_PASSWORD=$PODMAN_REGISTRY_PASSWORD
#----------------------------------------------------------
#----------------------------------------------------------
export SIDB_IMAGE=$SIDB_IMAGE
export GSM_IMAGE=$GSM_IMAGE
#----------------------------------------------------------
#----------------------------------------------------------
export DNS_PUBLIC_IP=$DNS_PUBLIC_IP
export NODE1_PUBLIC_IP=$NODE1_PUBLIC_IP
#----------------------------------------------------------
#----------------------------------------------------------
export DOMAIN_NAME=${DOMAIN_NAME}
export NODE1_HOSTNAME=${VM1_NAME}
export NODE1_FQ_HOSTNAME=\${NODE1_HOSTNAME}.\${DOMAIN_NAME}
#----------------------------------------------------------
#----------------------------------------------------------
export INFO='\033[0;34m信息：\033[0m'
export ERROR='\033[1;31m错误：\033[0m'
export SUCCESS='\033[1;32m成功：\033[0m'
#----------------------------------------------------------
#----------------------------------------------------------
EOL

# Setup the env
echo "-----------------------------------------------------------------"
echo -e "${INFO}`date +%F' '%T`: 正在配置环境变量"
echo "-----------------------------------------------------------------"
. /vagrant/config/setup.env
# 加载 Vagrant 生成的运行参数和统一日志样式。

# set system time zone
echo "-----------------------------------------------------------------"
echo -e "${INFO}`date +%F' '%T`: 系统时区已设置为 $SYSTEM_TIMEZONE"
echo "-----------------------------------------------------------------"
timedatectl set-timezone "$SYSTEM_TIMEZONE"


#--------------------------------------------------------------------
#--------------------------------------------------------------------
# Install OS Pachages
sh /vagrant/scripts/01_install_os_packages.sh

# Setting-up /u01 disk
sh /vagrant/scripts/02_setup_storage_container.sh $BOX_DISK_NUM $PROVIDER

# Setup shared disks
BOX_DISK_NUM=$((BOX_DISK_NUM + 1))
sh /vagrant/scripts/03_setup_oradata_disks.sh $BOX_DISK_NUM $PROVIDER

# 正在配置 /etc/hosts & /etc/resolv.conf
sh /vagrant/scripts/04_setup_hosts.sh

# Setup GDD
sh /vagrant/scripts/05_setup_GDD.sh

# run user-defined post-setup scripts
run_user_scripts;
#----------------------------------------------------------
# EndOfFile
#----------------------------------------------------------

