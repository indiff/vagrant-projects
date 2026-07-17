#!/bin/bash
#│▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒
#
# Copyright (c) 2024 Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at
# https://oss.oracle.com/licenses/upl.
#
# Since: August, 2024
# Author: ruggero.citton@oracle.com
# Description: 05_setup_GDD.sh
#
# DO NOT ALTER OR REMOVE COPYRIGHT NOTICES OR THIS HEADER.
#
#│▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒│

# 中文说明：
# - 此脚本创建 Podman 密钥、准备网络，并启动 GDD 所需的容器编排。
# - 仅翻译面向使用者的提示信息，保留命令、变量、路径与配置键原样。

. /vagrant/config/setup.env
# 加载 Vagrant 生成的运行参数和统一日志样式。

# Function to delete and create secrets
# 统一处理 Podman 密钥的重建，避免旧密钥残留。
delete_and_create_secret() {
    local secret_name=$1
    local file_path=$2

    # Check if the secret exists
    if podman secret inspect $secret_name &> /dev/null; then
        echo "信息：正在删除已有密钥 $secret_name..."
        podman secret rm $secret_name
    fi

    # Create the new secret
    echo "信息：正在创建新密钥 $secret_name..."
    podman secret create $secret_name $file_path
}

create_secrets() {
    # Check if SHARDING_SECRET environment variable is defined
    if [ -z "$SHARDING_SECRET" ]; then
        echo "错误：未定义 SHARDING_SECRET 环境变量。"
        return 1
    fi
    mkdir -p /opt/.secrets/
    echo $SHARDING_SECRET > /opt/.secrets/pwdfile.txt
    cd /opt/.secrets
    openssl genrsa -out key.pem
    openssl rsa -in key.pem -out key.pub -pubout
    openssl pkeyutl -in pwdfile.txt -out pwdfile.enc -pubin -inkey key.pub -encrypt
    rm -rf /opt/.secrets/pwdfile.txt
    # Delete and create secrets
    delete_and_create_secret "pwdsecret" "/opt/.secrets/pwdfile.enc"
    delete_and_create_secret "keysecret" "/opt/.secrets/key.pem"
    echo "信息：密钥已创建。"
    chown 54321:54321 /opt/.secrets/pwdfile.enc
    chown 54321:54321 /opt/.secrets/key.pem
    chown 54321:54321 /opt/.secrets/key.pub
    chmod 400 /opt/.secrets/pwdfile.enc
    chmod 400 /opt/.secrets/key.pem
    chmod 400 /opt/.secrets/key.pub
    # List of files
    # 这些目录会被容器直接挂载，需要补充 SELinux 上下文。
files=(
        "/opt/.secrets/pwdfile.enc"
        "/opt/.secrets/key.pem"
        /opt/.secrets/key.pub
    )
    if grep -q '^SELINUX=enforcing' /etc/selinux/config || grep -q '^SELINUX=permissive' /etc/selinux/config; then
        for file in "${files[@]}"; do
            # Check if file context exists
            if ! grep -q "$(basename "$file")" /etc/selinux/targeted/contexts/files/file_contexts.local; then
                # If not, add file context
                semanage fcontext -a -t container_file_t "$file"
                restorecon -v "$file"
            fi
        done
        echo "SELinux 已启用，已更新文件上下文。"

    fi

    cd -
    return 0
}

echo "-----------------------------------------------------------------"
echo -e "${INFO}`date +%F' '%T`: 正在配置密钥"
echo "-----------------------------------------------------------------"
create_secrets

echo "-----------------------------------------------------------------"
echo -e "${INFO}`date +%F' '%T`: 正在配置 Podman 网络"
echo "-----------------------------------------------------------------"
podman network create -d macvlan --subnet=10.0.20.0/24 --gateway=10.0.20.1 -o parent=eth0 shard_pub1_nw


if [ ! -z ${PODMAN_REGISTRY_URI} ] && [ ! -z ${PODMAN_REGISTRY_USER} ] && [ ! -z ${PODMAN_REGISTRY_PASSWORD} ]; then
  echo "-----------------------------------------------------------------"
  echo -e "${INFO}`date +%F' '%T`: 正在登录 $PODMAN_REGISTRY_URI"
  echo "-----------------------------------------------------------------"
  expect <<EOF
spawn podman login -u $PODMAN_REGISTRY_USER $PODMAN_REGISTRY_URI
while (1) {
  expect {
    -re ".*Password:.*" { send "$PODMAN_REGISTRY_PASSWORD\r" }
    "Error response from daemon:*" { exit 1 }
    eof { break }
  }
}
EOF
  if [ $? != 0 ]; then
   echo -e "${ERROR} 登录 '$PODMAN_REGISTRY_URI' 失败，正在退出..."
   exit 1
  fi
fi


echo "-----------------------------------------------------------------"
echo -e "${INFO}`date +%F' '%T`: 正在运行 GDD podman-compose"
echo "-----------------------------------------------------------------"
source /vagrant/scripts/podman-compose-prerequisites-free.sh
source /vagrant/scripts/set-file-context.sh
cd /vagrant/scripts
podman-compose up -d

#----------------------------------------------------------
# EndOfFile
#----------------------------------------------------------
