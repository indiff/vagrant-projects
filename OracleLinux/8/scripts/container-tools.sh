#!/usr/bin/env bash
#
# Provisioning script for the Container Tools module
#
# Copyright (c) 2020 Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at
# https://oss.oracle.com/licenses/upl.
#
# Description: Installs the podman, buildah and skopeo Container Tools
#
# DO NOT ALTER OR REMOVE COPYRIGHT NOTICES OR THIS HEADER.
#
# 中文说明：
# - 此脚本安装 Podman、Buildah 与 Skopeo 所需的 Container Tools 组件。
# - 仅翻译面向使用者的提示信息，保留命令、变量、路径与配置键原样。

echo '正在安装 Container Tools 模块'

dnf -y module install container-tools:ol8

echo 'Container Tools 已可使用'
echo '要开始使用，请在宿主机上运行：'
echo '  vagrant ssh'
echo
echo '然后在来宾系统中运行（例如）：'
echo '  podman run -it --rm oraclelinux:8-slim'
echo
