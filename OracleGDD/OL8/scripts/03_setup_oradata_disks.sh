#!/bin/bash
#│▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒
#
# Copyright (c) 2024 Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at
# https://oss.oracle.com/licenses/upl.
#
# Since: August, 2024
# Author: ruggero.citton@oracle.com
# Description: 03_setup_oradata_disks.sh
#
# DO NOT ALTER OR REMOVE COPYRIGHT NOTICES OR THIS HEADER.
#
#│▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒│

# 中文说明：
# - 此脚本为 /scratch/oradata 初始化分片数据库使用的数据磁盘与卷组。
# - 仅翻译面向使用者的提示信息，保留命令、变量、路径与配置键原样。

echo "-----------------------------------------------------------------"
echo -e "${INFO}`date +%F' '%T`: 正在设置 '/scratch/oradata'"
echo "-----------------------------------------------------------------"
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
SDISKSNUM=$(ls -l /dev/${DEVICE}[${LETTER}-z]|wc -l)
for (( i=1; i<=$SDISKSNUM; i++ ))
do
  parted /dev/${DEVICE}${LETTER} --script -- mklabel gpt mkpart primary 4096s 100%
  LETTER=$(echo "$LETTER" | tr "0-9a-z" "1-9a-z_")
done

#echo "-----------------------------------------------------------------"
#echo -e "${INFO}`date +%F' '%T`: Making 'LogVolData' LVM Group"
#echo "-----------------------------------------------------------------"
LETTER=`tr 0123456789 abcdefghij <<< $BOX_DISK_NUM`
SDISKSNUM=$(ls -l /dev/${DEVICE}[${LETTER}-z]|wc -l)
for (( i=1; i<=$SDISKSNUM; i++ ))
do
  pvcreate /dev/${DEVICE}${LETTER}1
  LETTER=$(echo "$LETTER" | tr "0-9a-z" "1-9a-z_")
done

LETTER=`tr 0123456789 abcdefghij <<< $BOX_DISK_NUM`
SDISKS=$(ls /dev/${DEVICE}[${LETTER}-z]1)
vgcreate VolGroupOra ${SDISKS}

lvcreate -l 100%FREE -n LogVolData VolGroupOra

# Make XFS
mkfs.xfs -f /dev/VolGroupOra/LogVolData

# Set fstab
UUID=`blkid -s UUID -o value /dev/VolGroupOra/LogVolData`
mkdir -p /scratch/oradata
# 将新卷写入 fstab，确保系统重启后自动挂载。
cat >> /etc/fstab <<EOF
UUID=${UUID}  /scratch/oradata    xfs    defaults 1 2
EOF

# Mount
mount /scratch/oradata

#----------------------------------------------------------
# EndOfFile
#----------------------------------------------------------

