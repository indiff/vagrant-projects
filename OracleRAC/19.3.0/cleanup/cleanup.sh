#!/usr/bin/env bash
#------------------------------------------------------------------------------
# LICENSE UPL 1.0
# Copyright (c) 1982-2026 Oracle and/or its affiliates. All rights reserved.
#
# cleanup.sh
#   Tear down the RAC lab and remove the shared ASM disks (and per-node u01
#   disks on VirtualBox) that `vagrant destroy` intentionally leaves behind —
#   shared media isn't auto-deleted because it can belong to multiple VMs, but
#   in this project it's always project-scoped, so full cleanup is desired.
#------------------------------------------------------------------------------
# 中文说明：
# - 此脚本在 Linux 上销毁 RAC 实验环境，并删除共享 ASM 磁盘与节点专用磁盘。
# - 仅翻译面向使用者的提示信息，保留命令、变量、路径与配置键原样。

set -euo pipefail

cd "$(dirname "$0")/.."

CONFIG=./config/vagrant.yml
[[ -f Vagrantfile ]] || { echo "错误：未找到 Vagrantfile；请从项目根目录运行" >&2; exit 1; }
[[ -f "$CONFIG"   ]] || { echo "错误：未找到 $CONFIG" >&2; exit 1; }

# Minimal YAML scalar reader for the flat 2-level structure vagrant.yml uses
# (top-level section, then 2-space-indented key: value lines). Avoids a ruby /
# pyyaml dependency — Vagrant's embedded Ruby isn't on PATH.
# 轻量解析 vagrant.yml，避免依赖额外的 Ruby/Python YAML 库。
yaml_get() {
  local section="$1" key="$2"
  awk -v s="$section" -v k="$key" '
    /^[A-Za-z_][A-Za-z0-9_]*:/ { cur = $1; sub(/:.*/, "", cur); next }
    cur == s {
      line = $0
      sub(/^[[:space:]]+/, "", line)
      if (line == "" || line ~ /^#/) next
      idx = index(line, ":")
      if (idx == 0) next
      if (substr(line, 1, idx-1) != k) next
      val = substr(line, idx+1)
      sub(/#.*$/, "", val)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", val)
      print val
      exit
    }
  ' "$CONFIG"
}

PROVIDER=$(yaml_get env provider)
PREFIX=$(yaml_get env prefix_name)
ASM_NUM=$(yaml_get env asm_disk_num)
ASM_PATH=$(yaml_get env asm_disk_path)
POOL=$(yaml_get env storage_pool_name)

if [[ -z "$PROVIDER" || -z "$PREFIX" || -z "$ASM_NUM" ]]; then
  echo "错误：必须在 $CONFIG 中设置 env.provider / shared.prefix_name / shared.asm_disk_num" >&2
  exit 1
fi

FORCE=0
case "${1-}" in
  -f|--force) FORCE=1 ;;
  -h|--help)  cat <<EOF
用法：$0 [-f|--force]
  运行 'vagrant destroy -f' 并删除已配置 provider 的共享 ASM 磁盘
  provider 为 $PROVIDER。传入 -f 可跳过确认提示。
EOF
              exit 0 ;;
esac

if [[ $FORCE -eq 0 ]]; then
  cat <<EOF
将执行以下操作：
  1. vagrant destroy -f
  2. 删除 ${ASM_NUM} 个共享 ASM 磁盘（provider：${PROVIDER}）
EOF
  [[ "$PROVIDER" == "virtualbox" ]] && echo "  3. 删除每个节点的 u01 磁盘（node1_u01.vdi、node2_u01.vdi）"
  echo ""
  read -rp "是否继续？[y/N] " ans
  [[ "$ans" =~ ^[yY]$ ]] || { echo "已取消。"; exit 0; }
fi

echo "=== 正在执行 vagrant destroy -f ==="
vagrant destroy -f || true

vbox_close_and_delete() {
  local path="$1"
  if VBoxManage list hdds 2>/dev/null | grep -Fq "$path"; then
    VBoxManage closemedium disk "$path" --delete 2>/dev/null \
      || VBoxManage closemedium disk "$path" 2>/dev/null \
      || true
  fi
  rm -f "$path"
}

case "$PROVIDER" in
  libvirt)
    POOL="${POOL:-default}"
    echo "=== 正在从 libvirt 存储池删除 ASM 卷 '$POOL' ==="
    for ((i=0; i<ASM_NUM; i++)); do
      vol="${PREFIX}_asm_${i}"
      if virsh vol-info --pool "$POOL" "$vol" >/dev/null 2>&1; then
        virsh vol-delete --pool "$POOL" "$vol"
      else
        echo "  跳过：$vol（不存在）"
      fi
    done
    virsh pool-refresh "$POOL" >/dev/null 2>&1 || true
    ;;
  virtualbox)
    dir="${ASM_PATH%/}"
    [[ -z "$dir" ]] && dir="."
    echo "=== 正在从 $dir 删除 VirtualBox 共享 ASM 磁盘 ==="
    for ((i=0; i<ASM_NUM; i++)); do
      vbox_close_and_delete "$(realpath -m "$dir/asm_disk${i}.vdi")"
    done
    echo "=== 正在删除每个节点的 u01 磁盘 ==="
    for node_disk in node1_u01.vdi node2_u01.vdi; do
      vbox_close_and_delete "$(realpath -m "./$node_disk")"
    done
    ;;
  *)
    echo "错误：unknown provider '$PROVIDER' in $CONFIG" >&2
    exit 1
    ;;
esac

echo "清理完成。"
