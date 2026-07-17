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
# - 为 u01 专用磁盘创建分区、LVM 和 XFS 文件系统。
# - 仅在 /etc/fstab 缺少对应 UUID 时追加挂载项，保证脚本可重复执行。

. /vagrant/scripts/_common.sh
require_root

if [[ $# -lt 2 ]]; then
  log_error "用法：$0 <disk-index> <provider>"
  exit 1
fi

box_disk_num="$1"
provider="$2"

# 中文：不同 provider 的磁盘设备命名规则不同，需先换算前缀。
case "${provider}" in
  libvirt)    dev_prefix="vd" ;;
  virtualbox) dev_prefix="sd" ;;
  *)          log_error "不支持的 provider：'${provider}'"; exit 1 ;;
esac

letter="$(tr 0123456789 abcdefghij <<< "${box_disk_num}")"
device="/dev/${dev_prefix}${letter}"

if [[ ! -b "${device}" ]]; then
  log_error "预期的块设备 ${device} 不存在"
  exit 1
fi

log_section "在 ${device} 上创建 GPT 和单分区"
parted -s -a optimal "${device}" mklabel gpt -- mkpart primary 2048s 100%
# Settle udev so the partition node appears before pvcreate
udevadm settle || true

log_section "在 ${device}1 上创建 LVM VolGroupU01 / LogVolU01"
pvcreate -ff -y "${device}1"
vgcreate VolGroupU01 "${device}1"
lvcreate -l 100%FREE -n LogVolU01 VolGroupU01

log_section "将 /dev/VolGroupU01/LogVolU01 格式化为 XFS"
mkfs.xfs -f /dev/VolGroupU01/LogVolU01

log_section "挂载 /u01"
uuid="$(blkid -s UUID -o value /dev/VolGroupU01/LogVolU01)"
mkdir -p /u01

# 中文：仅在缺少条目时写入 fstab，避免重复挂载配置。
fstab_line="UUID=${uuid}  /u01  xfs  defaults  1 2"
if ! grep -q "^UUID=${uuid}[[:space:]]" /etc/fstab; then
  printf '%s\n' "${fstab_line}" >> /etc/fstab
fi
mount /u01
