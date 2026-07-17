#!/usr/bin/env bash
#------------------------------------------------------------------------------
# LICENSE UPL 1.0
# Copyright (c) 1982-2026 Oracle and/or its affiliates. All rights reserved.
#
# 03_setup_oradata_disks.sh
#   Partition + LVM + XFS on all remaining oradata disks, mount on /u02.
#
#   Args:
#     $1 = index of the first oradata disk (0-based, i.e. after /u01)
#     $2 = provider name ('libvirt' or 'virtualbox')
#------------------------------------------------------------------------------

# 中文说明：
# - 扫描除 u01 之外的所有 oradata 数据盘，并统一创建卷组。
# - 最终把 Oracle 数据目录挂载到 /u02，供主备库共用相同布局。

. /vagrant/scripts/_common.sh
require_root

if [[ $# -lt 2 ]]; then
  log_error "用法：$0 <first-disk-index> <provider>"
  exit 1
fi

first_idx="$1"
provider="$2"

# 中文：根据 provider 推导块设备前缀，确保只处理目标数据盘。
case "${provider}" in
  libvirt)    dev_prefix="vd" ;;
  virtualbox) dev_prefix="sd" ;;
  *)          log_error "不支持的 provider：'${provider}'"; exit 1 ;;
esac

first_letter="$(tr 0123456789 abcdefghij <<< "${first_idx}")"

# Collect all disks from the first oradata letter up to z
shopt -s nullglob
disks=( /dev/${dev_prefix}[${first_letter}-z] )
if [[ ${#disks[@]} -eq 0 ]]; then
  log_error "在 /dev/${dev_prefix}[${first_letter}-z] 下未找到 oradata 磁盘"
  exit 1
fi

log_section "为 ${#disks[@]} 块 oradata 磁盘分区：${disks[*]}"
for d in "${disks[@]}"; do
  parted -s -a optimal "${d}" mklabel gpt -- mkpart primary 4096s 100%
done
udevadm settle || true

log_section "创建 PV"
for d in "${disks[@]}"; do
  pvcreate -ff -y "${d}1"
done

log_section "创建卷组 VolGroupOra 和逻辑卷 LogVolData"
# 中文：收集所有数据分区，一次性创建卷组和逻辑卷。
partitions=()
for d in "${disks[@]}"; do
  partitions+=( "${d}1" )
done
vgcreate VolGroupOra "${partitions[@]}"
lvcreate -l 100%FREE -n LogVolData VolGroupOra

log_section "将 /dev/VolGroupOra/LogVolData 格式化为 XFS"
mkfs.xfs -f /dev/VolGroupOra/LogVolData

log_section "挂载 /u02"
uuid="$(blkid -s UUID -o value /dev/VolGroupOra/LogVolData)"
mkdir -p /u02
if ! grep -q "^UUID=${uuid}[[:space:]]" /etc/fstab; then
  printf '%s\n' "UUID=${uuid}  /u02  xfs  defaults  1 2" >> /etc/fstab
fi
mount /u02
