#！/bin/bash
# 本脚本用于设置 Oracle RAC 环境下的共享磁盘分区及 udev 规则
# 适用于 VirtualBox、libvirt 等虚拟化环境
#│▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒
#
# LICENSE UPL 1.0
#
# Copyright (c) 1982-2024 Oracle and/or its affiliates. All rights reserved.
#
#    NAME
#      05_setup_shared_disks.sh 
#
#    DESCRIPTION
#      Setting-up shared disks partitions & udev rules
#
#    NOTES
#       DO NOT ALTER OR REMOVE COPYRIGHT NOTICES OR THIS HEADER.
#
#    AUTHOR
#       Ruggero Citton - RAC Pack, Cloud Innovation and Solution Engineering Team
#
#    MODIFIED   (MM/DD/YY)
#    rcitton     08/27/21 - ASMFD support added #335 + ASMFD with libvirt 
#    rcitton     03/30/20 - VBox libvirt & kvm support
#    rcitton     11/06/18 - Creation
#
#    REVISION
#    20240603 - $Revision: 2.0.2.2 $
#
#│▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒│
# 加载环境变量配置文件，包含主机名、磁盘数量等参数
set -xva
. /vagrant/config/setup.env

# 获取传入的参数：BOX_DISK_NUM 表示第几个磁盘，PROVIDER 表示虚拟化提供者（libvirt/virtualbox）
BOX_DISK_NUM=$1   # 共享磁盘编号
PROVIDER=$2       # 虚拟化平台类型

# 打印分割线和当前操作信息
echo "-----------------------------------------------------------------"
echo -e "${INFO}`date +%F' '%T`: 正在设置共享磁盘分区，磁盘编号：${BOX_DISK_NUM}，虚拟化平台：${PROVIDER}"
echo "-----------------------------------------------------------------"

# 根据虚拟化平台类型，确定磁盘设备前缀（libvirt 为 vd，virtualbox 为 sd）
if [ "${PROVIDER}" == "libvirt" ]; then
  DEVICE="vd"
elif [ "${PROVIDER}" == "virtualbox" ]; then
  DEVICE="sd"
else
  echo "不支持的虚拟化平台: ${PROVIDER}"
  exit 1
fi

# 仅在 NODE2 或 NODE1（ORESTART=true）上进行分区操作
if [[ `hostname` == ${NODE2_HOSTNAME} || (`hostname` == ${NODE1_HOSTNAME} && "${ORESTART}" == "true") ]]
then
  # 将磁盘编号转换为字母（如 1->b, 2->c 等）
  LETTER=`tr 0123456789 abcdefghij <<< $BOX_DISK_NUM`
  # 统计当前设备下有多少块共享磁盘
  SDISKSNUM=$(ls -l /dev/${DEVICE}[${LETTER}-z]|wc -l)
  for (( i=1; i<=$SDISKSNUM; i++ ))
  do
    # 使用 parted 工具创建 GPT 分区表和两个主分区
    # 第一个分区从 4096s 到 P1_RATIO%（如 50%）
    parted /dev/${DEVICE}${LETTER} --script -- mklabel gpt mkpart primary 4096s ${P1_RATIO}%
    # 第二个分区从 P1_RATIO% 到 100%
    parted /dev/${DEVICE}${LETTER} --script -- mkpart primary ${P1_RATIO}% 100%

    echo "Done! /dev/${DEVICE}${LETTER}"
    # 递增字母，处理下一个磁盘
    LETTER=$(echo "$LETTER" | tr "0-9a-z" "1-9a-z_")
  done
fi

# 打印分割线和 udev 规则设置信息
echo "-----------------------------------------------------------------"
echo -e "${INFO}`date +%F' '%T`: 正在设置共享磁盘 udev 规则"
echo "-----------------------------------------------------------------"
# 重新获取磁盘字母和数量，生成 udev 规则
LETTER=`tr 0123456789 abcdefghij <<< $BOX_DISK_NUM`
SDISKSNUM=$(ls -l /dev/${DEVICE}[${LETTER}-z]|wc -l)
if [ "${PROVIDER}" == "libvirt" ]; then
  for (( i=1; i<=$SDISKSNUM; i++ ))
  do
    # 针对 libvirt，直接写入 udev 规则，指定序列号、分区类型、权限等
    echo "KERNEL==\"${DEVICE}${LETTER}\",  SUBSYSTEM==\"block\", ENV{ID_SERIAL}==\"asm_disk_${i}\", ENV{ID_PART_TABLE_TYPE}==\"gpt\", SYMLINK+==\"ORCL_DISK${i}\"   , OWNER=\"grid\", GROUP=\"asmadmin\", MODE=\"0660\"" >> /etc/udev/rules.d/70-persistent-disk.rules
    echo "KERNEL==\"${DEVICE}${LETTER}1\", SUBSYSTEM==\"block\", ENV{ID_SERIAL}==\"asm_disk_${i}\", ENV{ID_PART_ENTRY_NUMBER}==\"1\", SYMLINK+==\"ORCL_DISK${i}_p1\", OWNER=\"grid\", GROUP=\"asmadmin\", MODE=\"0660\"" >> /etc/udev/rules.d/70-persistent-disk.rules
    echo "KERNEL==\"${DEVICE}${LETTER}2\", SUBSYSTEM==\"block\", ENV{ID_SERIAL}==\"asm_disk_${i}\", ENV{ID_PART_ENTRY_NUMBER}==\"2\", SYMLINK+==\"ORCL_DISK${i}_p2\", OWNER=\"grid\", GROUP=\"asmadmin\", MODE=\"0660\"" >> /etc/udev/rules.d/70-persistent-disk.rules
    echo "Done! cat /etc/udev/rules.d/70-persistent-disk.rules"
    LETTER=$(echo "$LETTER" | tr "0-9a-z" "1-9a-z_")
  done
elif [ "${PROVIDER}" == "virtualbox" ]; then
  for (( i=1; i<=$SDISKSNUM; i++ ))
  do
    # 针对 virtualbox，需动态获取磁盘序列号，写入 udev 规则
    echo "KERNEL==\"${DEVICE}${LETTER}\",  ENV{ID_SERIAL}==\"`udevadm info --query=all --name=/dev/${DEVICE}${LETTER} | grep ID_SERIAL= | awk -F \"=\" '{print $2}'`\", SYMLINK+=\"ORCL_DISK${i}\",    OWNER=\"grid\", GROUP=\"asmadmin\", MODE=\"0660\"" >> /etc/udev/rules.d/70-persistent-disk.rules
    echo "KERNEL==\"${DEVICE}${LETTER}1\", ENV{ID_SERIAL}==\"`udevadm info --query=all --name=/dev/${DEVICE}${LETTER} | grep ID_SERIAL= | awk -F \"=\" '{print $2}'`\", SYMLINK+=\"ORCL_DISK${i}_p1\", OWNER=\"grid\", GROUP=\"asmadmin\", MODE=\"0660\"" >> /etc/udev/rules.d/70-persistent-disk.rules
    echo "KERNEL==\"${DEVICE}${LETTER}2\", ENV{ID_SERIAL}==\"`udevadm info --query=all --name=/dev/${DEVICE}${LETTER} | grep ID_SERIAL= | awk -F \"=\" '{print $2}'`\", SYMLINK+=\"ORCL_DISK${i}_p2\", OWNER=\"grid\", GROUP=\"asmadmin\", MODE=\"0660\"" >> /etc/udev/rules.d/70-persistent-disk.rules
    echo "Done! cat /etc/udev/rules.d/70-persistent-disk.rules"
    LETTER=$(echo "$LETTER" | tr "0-9a-z" "1-9a-z_")
  done
fi

# 打印分割线和 partprobe 操作信息
echo "-----------------------------------------------------------------"
echo -e "${INFO}`date +%F' '%T`: 共享磁盘分区表刷新 (partprobe)"
echo "-----------------------------------------------------------------"
# 再次获取磁盘字母和数量，对每个分区执行 partprobe 刷新分区表，并设置权限
LETTER=`tr 0123456789 abcdefghij <<< $BOX_DISK_NUM`
SDISKSNUM=$(ls -l /dev/${DEVICE}[${LETTER}-z]|wc -l)
for (( i=1; i<=$SDISKSNUM; i++ ))
do
  # 刷新分区表，使新分区立即生效
  /sbin/partprobe /dev/${DEVICE}${LETTER}1
  /sbin/partprobe /dev/${DEVICE}${LETTER}2

  # 设置磁盘及分区的属主和属组为 grid:asmadmin，权限为 0660
  chown grid:asmadmin /dev/${DEVICE}${LETTER}
  chown grid:asmadmin /dev/${DEVICE}${LETTER}1
  chown grid:asmadmin /dev/${DEVICE}${LETTER}2

  echo "/sbin/partprobe /dev/${DEVICE}${LETTER}1!"
  echo "/sbin/partprobe /dev/${DEVICE}${LETTER}2!"
  # 递增字母，处理下一个磁盘
  LETTER=$(echo "$LETTER" | tr "0-9a-z" "1-9a-z_")
done

sleep 10

# 重新加载 udev 规则，使新规则生效
/sbin/udevadm control --reload-rules
/sbin/udevadm trigger --type=devices --action=change

LETTER=`tr 0123456789 abcdefghij <<< $BOX_DISK_NUM`
SDISKSNUM=$(ls -l /dev/${DEVICE}[${LETTER}-z]|wc -l)
for (( i=1; i<=$SDISKSNUM; i++ ))
do
  # 刷新分区表，使新分区立即生效
  /sbin/partprobe /dev/${DEVICE}${LETTER}1
  /sbin/partprobe /dev/${DEVICE}${LETTER}2

  echo "/sbin/partprobe /dev/${DEVICE}${LETTER}1!"
  echo "/sbin/partprobe /dev/${DEVICE}${LETTER}2!"
  # 递增字母，处理下一个磁盘
  LETTER=$(echo "$LETTER" | tr "0-9a-z" "1-9a-z_")
done

sleep 10

# 重新加载 udev 规则，使新规则生效
/sbin/udevadm control --reload-rules
/sbin/udevadm trigger --type=devices --action=change
sleep 10
# ls -al /dev/ORCL*
ls -ltr /dev/ORCL*
#----------------------------------------------------------
# 文件结束
#----------------------------------------------------------

