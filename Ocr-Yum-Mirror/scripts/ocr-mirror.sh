#!/bin/bash
#
# LICENSE UPL 1.0
#
# Copyright (c) 1982-2022 Oracle and/or its affiliates. All rights reserved.
#
# Since: August, 2022
# Author: simon.coter@oracle.com
# Description: Setup the Oracle Container Registry Mirror
# Manual steps available at https://docs.oracle.com/en/operating-systems/oracle-linux/podman/podman-UsingContainerRegistries.html#podman-ocr-local-mirror
#
# DO NOT ALTER OR REMOVE COPYRIGHT NOTICES OR THIS HEADER.
#

# 中文说明：
# - 创建本地 Oracle Container Registry 镜像服务。
# - 生成证书、启动 registry 容器并同步初始 OCNE 镜像。

echo 'OCR 镜像配置：开始执行'

# Software Install & system configuration
# sudo dnf install -y podman
sudo dnf install -y openssl
sudo firewall-cmd --zone=public --add-port=5000/tcp --permanent 
sudo systemctl reload firewalld.service
sudo dnf install -y olcne-utils

# disable SELINUX
# sudo setenforce 0
# sudo sed -i 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config

# system configuration - ocr mirror
# 中文：生成自签名证书并准备 rootless registry 的数据目录。
openssl req -x509 -newkey rsa:4096 -keyout /vagrant/ocr-yum-mirror.key -nodes -out /vagrant/ocr-yum-mirror.crt -sha256 -subj '/CN=ocr-yum-mirror' -addext "subjectAltName = DNS:ocr-yum-mirror,IP:10.0.2.2" -days 3650
mkdir /var/yum/registry
sudo /usr/sbin/semanage fcontext -a -t user_home_t "/var/yum/registry(/.*)?"
mkdir /var/yum/registry/conf.d
cp /vagrant/ocr-yum-mirror.crt /var/yum/registry/conf.d/
cp /vagrant/ocr-yum-mirror.key /var/yum/registry/conf.d/
sudo cp /vagrant/ocr-yum-mirror.crt /etc/pki/ca-trust/source/anchors/
sudo update-ca-trust

# Allow podman rootless container in detached mode to run beyond logout
sudo loginctl enable-linger

# start container-registry mirror container
podman run -d -p 5000:5000 --name ocr-yum-mirror --restart=always \
    -v /var/yum/registry:/registry_data:Z \
    -e REGISTRY_STORAGE_FILESYSTEM_ROOTDIRECTORY=/registry_data \
    -e REGISTRY_HTTP_TLS_KEY=/registry_data/conf.d/ocr-yum-mirror.key \
    -e REGISTRY_HTTP_TLS_CERTIFICATE=/registry_data/conf.d/ocr-yum-mirror.crt \
    -e REGISTRY_AUTH="" \
    container-registry.oracle.com/os/registry:v2.7.1.1

# add sync script for OCR mirror
# 中文：封装同步命令，便于后续重复拉取 OCR 镜像。
cat <<EOF | tee /home/vagrant/sync-ocr.sh
/usr/bin/registry-image-helper.sh --to ocr-yum-mirror:5000/olcne $*
EOF
chmod 700 /home/vagrant/sync-ocr.sh

# collect OCNE container images
/home/vagrant/sync-ocr.sh --version 1.25.7

echo 'OCR 镜像配置：已完成'
