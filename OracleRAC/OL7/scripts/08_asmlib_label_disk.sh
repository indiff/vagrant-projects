#！/bin/bash
# 本脚本用于为 Oracle ASMLib 设备打标签，适用于 VirtualBox、libvirt 等虚拟化环境
#│▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒
#
# LICENSE UPL 1.0
#
# Copyright (c) 1982-2024 Oracle and/or its affiliates. All rights reserved.
#
#    NAME
#      08_asmlib_label_disk.sh
#
#    DESCRIPTION
#      Setup ASMLib disks
#
#    NOTES
#       DO NOT ALTER OR REMOVE COPYRIGHT NOTICES OR THIS HEADER.
#
#    AUTHOR
#       Ruggero Citton - RAC Pack, Cloud Innovation and Solution Engineering Team
#
#    MODIFIED   (MM/DD/YY)
#    rcitton     03/30/20 - VBox libvirt & kvm support
#    rcitton     11/06/18 - Creation
#
#    REVISION
#    20240603 - $Revision: 2.0.2.1 $
#
#│▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒│

# 加载环境变量配置文件，包含主机名、磁盘数量等参数
. /vagrant/config/setup.env
# 获取传入的参数：BOX_DISK_NUM 表示第几个磁盘，PROVIDER 表示虚拟化提供者（libvirt/virtualbox）
BOX_DISK_NUM=$1   # 共享磁盘编号
PROVIDER=$2       # 虚拟化平台类型

# 根据虚拟化平台类型，确定磁盘设备前缀（libvirt 为 vd，virtualbox 为 sd）
if [ "${PROVIDER}" == "libvirt" ]; then
  DEVICE="vd"
elif [ "${PROVIDER}" == "virtualbox" ]; then
  DEVICE="sd"
else
  echo "不支持的虚拟化平台: ${PROVIDER}"
  exit 1
fi


# 配置并初始化 oracleasm，指定属主 grid、属组 asmadmin，自动启动
/usr/sbin/oracleasm configure -u grid -g asmadmin -e -b -s y
/usr/sbin/oracleasm init


# 为每块磁盘的第一个分区创建 ASMLib 磁盘标签
LETTER=`tr 0123456789 abcdefghij <<< $BOX_DISK_NUM`   # 将磁盘编号转换为字母
SDISKSNUM=$(ls -l /dev/${DEVICE}[${LETTER}-z]|wc -l)  # 统计当前设备下有多少块共享磁盘
for (( i=1; i<=$SDISKSNUM; i++ ))
do
  DISK="ORCL_DISK${i}_P1"   # 标签名，P1 表示第一个分区
  DEVICE_PATH="/dev/${DEVICE}${LETTER}1";  # 分区设备路径
  # 使用 oracleasm 工具为分区创建 ASMLib 磁盘标签
  /usr/sbin/oracleasm createdisk ${DISK} ${DEVICE_PATH}
  # 递增字母，处理下一个磁盘
  LETTER=$(echo "$LETTER" | tr "0-9a-z" "1-9a-z_")
done


# 为每块磁盘的第二个分区创建 ASMLib 磁盘标签
LETTER=`tr 0123456789 abcdefghij <<< $BOX_DISK_NUM`
SDISKSNUM=$(ls -l /dev/${DEVICE}[${LETTER}-z]|wc -l)
for (( i=1; i<=$SDISKSNUM; i++ ))
do
  DISK="ORCL_DISK${i}_P2"   # 标签名，P2 表示第二个分区
  DEVICE_PATH="/dev/${DEVICE}${LETTER}2";  # 分区设备路径
  # 使用 oracleasm 工具为分区创建 ASMLib 磁盘标签
  /usr/sbin/oracleasm createdisk ${DISK} ${DEVICE_PATH}
  # 递增字母，处理下一个磁盘
  LETTER=$(echo "$LETTER" | tr "0-9a-z" "1-9a-z_")
done


# 扫描并列出所有 ASMLib 磁盘标签
/usr/sbin/oracleasm scandisks
/usr/sbin/oracleasm listdisks

#----------------------------------------------------------
# 文件结束
#----------------------------------------------------------
