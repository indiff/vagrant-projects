#!/usr/bin/env bash
#------------------------------------------------------------------------------
# LICENSE UPL 1.0
# Copyright (c) 1982-2026 Oracle and/or its affiliates. All rights reserved.
#
# 06_setup_shared_disks.sh
#   Partition each shared disk (P1 = DATA, P2 = RECO) on the node that owns
#   creation, and write udev rules so that both nodes expose the disks as
#   /dev/ORCL_DISK<n>[_p1|_p2] with grid:asmadmin ownership.
#
#   Args:
#     $1 = index of the first shared disk (0-based among the VM's disks)
#     $2 = provider name ('libvirt' or 'virtualbox')
#------------------------------------------------------------------------------
. /vagrant/scripts/_common.sh
require_root
for v in ASM_DISK_NUM NODE1_HOSTNAME NODE2_HOSTNAME; do
  require_var "${v}"
done

if [[ $# -lt 2 ]]; then
  log_error "usage: $0 <first-shared-disk-index> <provider>"
  exit 1
fi

first_idx="$1"
provider="$2"

dev_prefix="$(device_prefix_for_provider "${provider}")"

current_host="$(hostname -s)"

clear_block_device_metadata() {
  local dev="$1"
  local wipe_mib="${2:-16}"
  local bytes seek_mib wipe_bytes

  if [[ ! -b "${dev}" ]]; then
    log_error "expected block device ${dev} is missing"
    return 1
  fi

  log_info "clearing stale partition / ASM metadata on ${dev}"
  wipefs -a -f "${dev}" >/dev/null 2>&1 || true

  dd if=/dev/zero of="${dev}" bs=1M count="${wipe_mib}" conv=fsync >/dev/null 2>&1

  bytes="$(blockdev --getsize64 "${dev}")"
  wipe_bytes=$((wipe_mib * 1024 * 1024))
  if (( bytes > wipe_bytes )); then
    seek_mib=$(((bytes / 1024 / 1024) - wipe_mib))
    if (( seek_mib > 0 )); then
      dd if=/dev/zero of="${dev}" bs=1M seek="${seek_mib}" count="${wipe_mib}" conv=fsync,notrunc >/dev/null 2>&1
    fi
  fi
}

# --- Which disks do we own the partition table for? -------------------------
# In a two-node cluster, node2 is responsible (writes propagate); in a
# single-node cluster there's only one node, so node1 does it.
partition_here="true"

# --- Enumerate the shared disks (exactly ASM_DISK_NUM of them) --------------
letters=()
for ((i = 0; i < ASM_DISK_NUM; i++)); do
  pos=$((first_idx + i))
  letters+=("$(disk_suffix_from_index "${pos}")")
done

if [[ "${partition_here}" == "true" ]]; then
  for L in "${letters[@]}"; do
    dev="/dev/${dev_prefix}${L}"
    if [[ ! -b "${dev}" ]]; then
      log_error "expected shared block device ${dev} is missing"
      exit 1
    fi
    clear_block_device_metadata "${dev}"
    log_info "partitioning ${dev} (P1 = 100%)"
    parted -s "${dev}" -- \
      mklabel gpt \
      mkpart primary 4096s 100%
  done
  udevadm settle || true
fi

# --- udev rules (run on every node) -----------------------------------------
log_section "Installing udev rules for shared disks"
udev_file='/etc/udev/rules.d/70-oracle-asm.rules'
: > "${udev_file}"

i=1
for L in "${letters[@]}"; do
  dev="/dev/${dev_prefix}${L}"
  if [[ "${provider}" == "libvirt" ]]; then
    # Match only on KERNEL + ID_SERIAL: avoid blkid-probed env keys
    # (ID_PART_TABLE_TYPE / ID_PART_ENTRY_NUMBER) which can be transiently
    # unset during udev change-event re-evaluation and cause the SYMLINK
    # to disappear mid-discovery. Lock OWNER/GROUP/MODE with := so later
    # rules can't override.
    {
      echo "KERNEL==\"${dev_prefix}${L}\",  SUBSYSTEM==\"block\", ENV{ID_SERIAL}==\"asm_disk_${i}\", SYMLINK+=\"ORCL_DISK${i}\",    OWNER:=\"grid\", GROUP:=\"asmadmin\", MODE:=\"0660\""
      echo "KERNEL==\"${dev_prefix}${L}1\", SUBSYSTEM==\"block\", ENV{ID_SERIAL}==\"asm_disk_${i}\", SYMLINK+=\"ORCL_DISK${i}_p1\", OWNER:=\"grid\", GROUP:=\"asmadmin\", MODE:=\"0660\""
    } >> "${udev_file}"
  else
    serial="$(udevadm info --query=all --name="${dev}" | awk -F= '/^E: ID_SERIAL=/{print $2; exit}')"
    if [[ -z "${serial}" ]]; then
      log_error "could not determine ID_SERIAL for ${dev}"
      exit 1
    fi
    {
      echo "KERNEL==\"${dev_prefix}${L}\",  ENV{ID_SERIAL}==\"${serial}\", SYMLINK+=\"ORCL_DISK${i}\",    OWNER:=\"grid\", GROUP:=\"asmadmin\", MODE:=\"0660\""
      echo "KERNEL==\"${dev_prefix}${L}1\", ENV{ID_SERIAL}==\"${serial}\", SYMLINK+=\"ORCL_DISK${i}_p1\", OWNER:=\"grid\", GROUP:=\"asmadmin\", MODE:=\"0660\""
    } >> "${udev_file}"
  fi
  ((i++))
done
chmod 0644 "${udev_file}"
udevadm control --reload-rules
udevadm trigger --subsystem-match=block

log_section "Running partprobe + fixing ownership"
i=1
for L in "${letters[@]}"; do
  dev="/dev/${dev_prefix}${L}"
  /sbin/partprobe "${dev}" || true
  /sbin/partx -u "${dev}" || true
  udevadm settle || true
  chown_block_device "${dev}" grid:asmadmin
  chown_block_device "${dev}1" grid:asmadmin

  wait_for_block_device "/dev/ORCL_DISK${i}_p1"
  if [[ "${partition_here}" == "true" ]]; then
    clear_block_device_metadata "${dev}1"
  fi
  ((i++))
done
