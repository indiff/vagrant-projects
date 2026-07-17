#!/bin/bash

# 中文说明：
# - 此脚本为容器数据目录补充 SELinux 文件上下文。
# - 仅翻译面向使用者的提示信息，保留命令、变量、路径与配置键原样。

# 这些目录会被容器直接挂载，需要补充 SELinux 上下文。
files=(
        "${PODMANVOLLOC}/dbfiles/CATALOG"
        "/opt/containers/shard_host_file"
        "${PODMANVOLLOC}/dbfiles/ORCL1CDB"
        "${PODMANVOLLOC}/dbfiles/ORCL2CDB"
        "${PODMANVOLLOC}/dbfiles/GSMDATA"
        "${PODMANVOLLOC}/dbfiles/GSM2DATA"
        "${PODMANVOLLOC}/dbfiles/ORCL3CDB"
        "${PODMANVOLLOC}/dbfiles/ORCL4CDB"
    )

    # Check if SELinux is enabled (enforcing or permissive)
    if grep -q '^SELINUX=enforcing' /etc/selinux/config || grep -q '^SELINUX=permissive' /etc/selinux/config; then
        for file in "${files[@]}"; do
            semanage fcontext -a -t container_file_t "$file"
            restorecon -v "$file"
        done
        echo "SELinux 已启用，已更新文件上下文。"
    fi
