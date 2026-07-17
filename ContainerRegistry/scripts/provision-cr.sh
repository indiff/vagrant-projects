#!/bin/bash
#
# LICENSE UPL 1.0
#
# Copyright (c) 1982-2018 Oracle and/or its affiliates. All rights reserved.
#
# Since: June, 2018
# Author: philippe.vanhaesendonck@oracle.com
# Description: Installs Docker Engine and runs a registry container
#
# DO NOT ALTER OR REMOVE COPYRIGHT NOTICES OR THIS HEADER.
#

# 中文说明：
# - 在宿主机上启动本地 Docker Registry 容器。
# - 通过固定端口映射对外提供镜像推送与拉取服务。

# 中文：使用官方 registry:2 镜像启动长期运行的仓库服务。
echo "启动 Docker Registry"
docker run \
        --detach \
        --restart unless-stopped \
        --name registry \
        --publish 5000:5000 \
        registry:2

echo "Registry 虚拟机已可使用！"
