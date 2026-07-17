#!/bin/bash
#
# LICENSE UPL 1.0
#
# Copyright (c) 2018,2020 Oracle and/or its affiliates.
#
# Since: January, 2018
# Author: gerald.venzl@oracle.com
# Description: Updates Oracle Linux to the latest version
#
# DO NOT ALTER OR REMOVE COPYRIGHT NOTICES OR THIS HEADER.
#

# 中文说明：
# - 此脚本安装 Apache、MySQL 和 PHP，并生成基础的 LAMP 演示页面。
# - 仅翻译面向使用者的提示信息，保留命令、变量、路径与配置键原样。

echo '安装程序：正在启用 MySQL 和 Software Collection Yum 仓库'

# install yum-config-manager to get yum repos managed
yum install yum-utils -y

# enable software-collection yum repository
yum install -y oracle-softwarecollection-release-el7.x86_64

# enable MySQL yum repository
yum install mysql-release-el7.x86_64 -y

echo '安装程序：正在从 Oracle Linux Software Collections 安装 Apache Web 服务器'

# get Apache2 from software-collections installed and running
yum install httpd24 -y
systemctl enable httpd24-httpd
systemctl start httpd24-httpd

echo '安装程序：正在安装 MySQL Community Release 8'

# get MySQL Community 8
yum install mysql-community-server.x86_64 mysql-community-client.x86_64 -y
systemctl enable mysqld
systemctl start mysqld

echo '安装程序：正在从 Oracle Linux Software Collections 安装 PHP 7.3'
# get PHP 7.0
yum install rh-php73.x86_64 rh-php73-php rh-php73-php-mysqlnd.x86_64 rh-php73-php-fpm.x86_64 -y
systemctl enable rh-php73-php-fpm
systemctl start rh-php73-php-fpm

echo '安装程序：正在配置 Apache 服务器'
cat > /opt/rh/httpd24/root/var/www/html/info.php << EOF
<?php
phpinfo();
?>
EOF

systemctl restart httpd24-httpd

# 生成登录欢迎信息，提示实验环境中已启用的组件。
cat > /etc/motd << EOF

Welcome to Oracle Linux Server release 7
LAMP architecture based on Oracle Linux Software Collections:
 - Apache 2.4, MySQL Community 8 and PHP 7.3

The Oracle Linux End-User License Agreement can be viewed here:

    * /usr/share/eula/eula.en_US

For additional packages, updates, documentation and community help, see:

    * https://yum.oracle.com/

To test your environment is correctly working, just open following URL from your Host OS:
http://localhost:8080/info.php

Please use following commands to enable Software Collection environments:
- Apache 2.4: # scl enable httpd24 /bin/bash
- PHP 7.3: # scl enable rh-php73 /bin/bash
EOF
