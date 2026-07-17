#!/bin/bash
#
# LICENSE UPL 1.0
#
# Copyright (c) 1982-2018 Oracle and/or its affiliates. All rights reserved.
#
# Since: June, 2018
# Author: philippe.vanhaesendonck@oracle.com
# Description: Clone latest Kubernetes containers
#
# DO NOT ALTER OR REMOVE COPYRIGHT NOTICES OR THIS HEADER.
#

# 中文说明：
# - 登录上游镜像仓库并安装 kubeadm。
# - 将 Kubernetes 相关镜像同步到本地 Registry。

Registry="container-registry.oracle.com"
Repo="kubernetes"
YumOpts="--disablerepo ol7_developer"

# Parse arguments
# 中文：支持切换上游仓库地址和开发者仓库。
while [ $# -gt 0 ]
do
  case "$1" in
    "--from")
      if [ $# -lt 2 ]
      then
	echo "$0: 缺少参数"
	exit 1
      fi
      Registry="$2"
      shift; shift
      ;;
    "--dev")
      # Developer release
      Repo="kubernetes_developer"
      YumOpts=""
      shift
      ;;
    *)
      echo "$0: 无效参数"
      exit 1
      ;;
  esac
done

# 中文：先完成仓库认证，再执行镜像同步。
echo "$0: 登录到 ${Registry}"
docker login ${Registry}
if [ $? -ne 0 ]
then
  echo "$0: 认证失败"
  exit 1
fi

echo "$0: 正在安装 kubeadm"
sudo yum install -y ${YumOpts} kubeadm

echo "$0: 正在复制 Kubernetes 容器镜像"
/bin/kubeadm-registry.sh --to localhost:5000/kubernetes --from ${Registry}/${Repo}

echo "$0: 镜像复制完成！"
