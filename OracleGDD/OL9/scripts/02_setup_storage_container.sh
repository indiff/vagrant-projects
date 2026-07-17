#!/bin/bash
#│▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒
#
# Copyright (c) 2024 Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at
# https://oss.oracle.com/licenses/upl.
#
# Since: August, 2024
# Author: ruggero.citton@oracle.com
# Description: 02_setup_storage_container.sh
#
# DO NOT ALTER OR REMOVE COPYRIGHT NOTICES OR THIS HEADER.
#
#│▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒│

# 中文说明：
# - 此脚本为 /var/lib/containers 准备专用磁盘、LVM 与文件系统。
# - 仅翻译面向使用者的提示信息，保留命令、变量、路径与配置键原样。

echo "-----------------------------------------------------------------"
echo -e "${INFO}`date +%F' '%T`: 正在设置 '/var/lib/containers'"
echo "-----------------------------------------------------------------"
# Single GPT partition for the whole disk
BOX_DISK_NUM=$1
PROVIDER=$2

# 根据 provider 推导磁盘设备名前缀，兼容 libvirt 与 VirtualBox。
if [ "${PROVIDER}" == "libvirt" ]; then
  DEVICE="vd"
elif [ "${PROVIDER}" == "virtualbox" ]; then
  DEVICE="sd"
else
  echo "不支持的 provider：${PROVIDER}"
  exit 1
fi

LETTER=`tr 0123456789 abcdefghij <<< $BOX_DISK_NUM`
parted -s -a optimal /dev/${DEVICE}${LETTER} mklabel gpt -- mkpart primary 2048s 100%

# LVM setup
pvcreate /dev/${DEVICE}${LETTER}1
vgcreate VolGroupSC /dev/${DEVICE}${LETTER}1
lvcreate -l 100%FREE -n LogVolSC VolGroupSC

# Make XFS
mkfs.xfs -f /dev/VolGroupSC/LogVolSC

# Set fstab
UUID=`blkid -s UUID -o value /dev/VolGroupSC/LogVolSC`
mkdir -p /var/lib/containers
# 将新卷写入 fstab，确保系统重启后自动挂载。
cat >> /etc/fstab <<EOF
UUID=${UUID}  /var/lib/containers    xfs    defaults 1 2
EOF

# Mount
mount /var/lib/containers
#----------------------------------------------------------
# EndOfFile
#----------------------------------------------------------
