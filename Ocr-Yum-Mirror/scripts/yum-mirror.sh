#!/bin/bash
#
# LICENSE UPL 1.0
#
# Copyright (c) 1982-2022 Oracle and/or its affiliates. All rights reserved.
#
# Since: August, 2022
# Author: simon.coter@oracle.com
# Description: Setup the Yum mirror configuration
# Manual steps available at https://docs.oracle.com/en/learn/local_yum-mirror_linux_8/index.html#introduction
#
# DO NOT ALTER OR REMOVE COPYRIGHT NOTICES OR THIS HEADER.
#

# 中文说明：
# - 创建本地 Yum 镜像目录和同步脚本。
# - 同步常用 Oracle Linux 与 OCNE 软件仓库内容。

echo 'Yum 镜像配置：开始执行'

# Software Install
sudo dnf install -y yum-utils
sudo dnf install -y net-tools mlocate
sudo firewall-cmd --reload

# system configuration - yum mirror
# 中文：将同步目录暴露给 httpd，供局域网客户端访问。
sudo ln -s /var/yum /var/www/html/yum
sudo /usr/sbin/semanage fcontext -a -t httpd_sys_content_t "/var/yum(/.*)?"
sudo restorecon -RFv /var/yum

# add sync script for yum mirror
# 中文：生成仓库同步脚本，后续可重复刷新本地镜像。
cat <<EOF | tee /home/vagrant/sync-yum.sh
/usr/bin/reposync --newest-only --delete --download-metadata --exclude='*.src,*.nosrc' -p /var/yum --remote-time --repoid ol8_baseos_latest
/usr/bin/reposync --newest-only --delete --download-metadata --exclude='*.src,*.nosrc' -p /var/yum --remote-time --repoid ol8_appstream
/usr/bin/reposync --newest-only --delete --download-metadata --exclude='*.src,*.nosrc' -p /var/yum --remote-time --repoid ol8_olcne16
/usr/bin/reposync --newest-only --delete --download-metadata --exclude='*.src,*.nosrc' -p /var/yum --remote-time --repoid ol8_addons
/usr/bin/reposync --newest-only --delete --download-metadata --exclude='*.src,*.nosrc' -p /var/yum --remote-time --repoid ol8_UEKR6
/usr/bin/reposync --newest-only --delete --download-metadata --exclude='*.src,*.nosrc' -p /var/yum --remote-time --repoid ol8_UEKR7
EOF
chmod 700 /home/vagrant/sync-yum.sh

/home/vagrant/sync-yum.sh

echo 'Yum 镜像配置：已完成'
