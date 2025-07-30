#！/bin/bash
# 本脚本用于创建 Oracle ASM 的 RECO（恢复）磁盘组
#│▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒
#
# LICENSE UPL 1.0
#
# Copyright (c) 1982-2024 Oracle and/or its affiliates. All rights reserved.
#
#    NAME
#      12_Make_RECODG.sh
#
#    DESCRIPTION
#      Make RECO DG
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

# 加载环境变量配置文件，包含 GI_HOME、GI_VERSION、DB_VERSION 等参数
. /vagrant/config/setup.env
set -x
# 设置 ORACLE_HOME 为 GI_HOME
export ORACLE_HOME=${GI_HOME}
# 根据是否为 Oracle Restart，设置 ORACLE_SID
if [ "${ORESTART}" == "false" ]
then
  export ORACLE_SID=+ASM1   # 集群环境下节点1的 ASM 实例名
else
  export ORACLE_SID=+ASM    # 单节点 Oracle Restart 环境
fi


# 构造 ASM 磁盘组创建语句所需的磁盘字符串
DISKS_STRING=""
declare -a DEVICES
for device in /dev/ORCL_DISK*_p2
do
  # 将所有匹配的磁盘设备加入数组
  DEVICES=("${dev[@]}" "$device")
  # 获取设备名（如 ORCL_DISK1_P2）
  DISK=$(basename "$DEVICES")
  # 拼接成 ASM 语法所需格式
  DISKS_STRING=${DISKS_STRING}"DISK '"${DEVICES}"' NAME "${DISK}" "
done


# 使用 sqlplus 以 sysasm 身份连接 ASM 实例，创建 RECO 磁盘组
echo "DISKS_STRING: ${DISKS_STRING} "


cat <<EOF
CREATE DISKGROUP RECO NORMAL REDUNDANCY 
 ${DISKS_STRING}
 ATTRIBUTE 
   'compatible.asm'='${GI_VERSION}',         -- ASM 兼容性
   'compatible.rdbms'='${DB_VERSION}',       -- 数据库兼容性
   'sector_size'='512',                      -- 扇区大小
   'AU_SIZE'='4M',                           -- 分配单元大小
   'content.type'='recovery';                -- 磁盘组类型为恢复
EOF


${GI_HOME}/bin/sqlplus / as sysasm <<EOF
CREATE DISKGROUP RECO NORMAL REDUNDANCY
 ${DISKS_STRING}
 ATTRIBUTE
   'compatible.asm'='19.0',
   'compatible.rdbms'='19.0',
   'sector_size'='512',
   'AU_SIZE'='4M',
   'content.type'='recovery';
EOF



echo "******************************************************************************"
echo "Check cluster configuration." `date`
echo "******************************************************************************"
${GI_HOME}/bin/crsctl stat res -t

#----------------------------------------------------------
# 文件结束
#----------------------------------------------------------
