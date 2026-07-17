#!/usr/bin/env bash
#------------------------------------------------------------------------------
# LICENSE UPL 1.0
# Copyright (c) 1982-2026 Oracle and/or its affiliates. All rights reserved.
#
# 02_setup_u01.sh
#   Partition + LVM + XFS on the dedicated u01 disk, mount on /u01.
#
#   Args:
#     $1 = index of the u01 disk among the VM disks (0-based)
#     $2 = provider name ('libvirt' or 'virtualbox')
#------------------------------------------------------------------------------
# 中文说明：
# 用于初始化 u01 数据盘，并挂载为后续 Oracle 软件目录。

. /vagrant/scripts/_common.sh
require_root

if [[ $# -lt 2 ]]; then
  log_error "用法：$0 <disk-index> <provider>"
  exit 1
fi

box_disk_num="$1"
provider="$2"

dev_prefix="$(device_prefix_for_provider "${provider}")"

letter="$(disk_suffix_from_index "${box_disk_num}")"
device="/dev/${dev_prefix}${letter}"

if [[ ! -b "${device}" ]]; then
  log_error "期望的块设备 ${device} 不存在"
  exit 1
fi

# Idempotency: if /u01 is already mounted, skip.
# 中文：已挂载时直接跳过，避免重复分区和格式化。
if mountpoint -q /u01; then
  log_info "/u01 已挂载，跳过处理"
  exit 0
fi

log_section "正在在 ${device} 上创建 GPT 和单分区"
parted -s -a optimal "${device}" mklabel gpt -- mkpart primary 2048s 100%
udevadm settle || true

log_section "正在在 ${device}1 上创建 LVM VolGroupU01 / LogVolU01"
pvcreate -ff -y "${device}1"
vgcreate VolGroupU01 "${device}1"
lvcreate -l 100%FREE -n LogVolU01 VolGroupU01

log_section "正在将 /dev/VolGroupU01/LogVolU01 格式化为 XFS"
mkfs.xfs -f /dev/VolGroupU01/LogVolU01

log_section "正在挂载 /u01"
uuid="$(blkid -s UUID -o value /dev/VolGroupU01/LogVolU01)"
mkdir -p /u01

fstab_line="UUID=${uuid}  /u01  xfs  defaults  1 2"
if ! grep -q "^UUID=${uuid}[[:space:]]" /etc/fstab; then
  printf '%s\n' "${fstab_line}" >> /etc/fstab
fi
mount /u01
