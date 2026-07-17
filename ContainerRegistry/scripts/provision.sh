#!/bin/bash
#
# LICENSE UPL 1.0
#
# Copyright (c) 2018, 2020 Oracle and/or its affiliates.
#
# Since: March, 2018
# Author: philippe.vanhaesendonck@oracle.com
# Description: Installs Docker Engine and runs a registry container
#
# DO NOT ALTER OR REMOVE COPYRIGHT NOTICES OR THIS HEADER.
#

# 中文说明：
# - 安装 Docker Engine 及其存储依赖。
# - 准备 BTRFS 存储并启用 docker 服务。

echo "正在安装并配置 Docker Engine"

# Install Docker
yum install -y docker-engine btrfs-progs

# Create and mount a BTRFS partition for docker.
# 中文：将独立磁盘用于 Docker 数据目录，避免占满系统盘。
docker-storage-config -f -s btrfs -d /dev/[sv]db

# Add vagrant user to docker group
usermod -a -G docker vagrant

# Enable and start Docker
# 中文：开机自启并立即启动 Docker 服务。
systemctl enable docker
systemctl start docker
