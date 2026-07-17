#!/usr/bin/env bash
#------------------------------------------------------------------------------
# LICENSE UPL 1.0
# Copyright (c) 1982-2026 Oracle and/or its affiliates. All rights reserved.
#
# 05_setup_users.sh
#   Create oracle user, groups, shell limits and DB home directories.
#   The oracle user is created with a locked password; setup.sh sets it
#   afterwards via chpasswd.
#------------------------------------------------------------------------------

# 中文说明：
# - 重建 oracle 用户、数据库相关用户组以及 shell 资源限制。
# - 同时准备 ORACLE_HOME、ORADATA 目录和 oracle 用户环境文件。

. /vagrant/scripts/_common.sh
require_root
require_var DB_BASE
require_var DB_HOME
require_var DB_NAME
require_var NODE1_HOSTNAME
require_var NODE2_HOSTNAME

log_section "准备 oracle 用户和用户组"

# Drop any pre-existing oracle/groups from the base box. Failures are tolerated.
# 中文：先清理基础 box 中可能残留的 oracle 账户和用户组。
userdel  -fr  oracle     2>/dev/null || true
for g in oinstall dba backupdba dgdba kmdba racdba dbaoper; do
  groupdel "${g}" 2>/dev/null || true
done

groupadd -g 1001 oinstall
groupadd -g 1002 dbaoper
groupadd -g 1003 dba
groupadd -g 1007 backupdba
groupadd -g 1008 dgdba
groupadd -g 1009 kmdba
groupadd -g 1010 racdba

# Create oracle with a LOCKED password (!). setup.sh assigns the real password
# 中文：先创建锁定口令的 oracle 用户，再由 setup.sh 统一写入真实密码。
# afterwards via chpasswd — no cleartext on the command line.
useradd oracle \
  -d /home/oracle -m \
  -s /bin/bash \
  -g oinstall \
  -G dbaoper,dba,backupdba,dgdba,kmdba,racdba \
  -p '!'

log_section "设置 oracle shell 限制"
limits_file='/etc/security/limits.d/99-oracle.conf'
cat > "${limits_file}" <<'EOF'
# Oracle user limits (managed by Vagrant provisioner)
oracle soft nofile   131072
oracle hard nofile   131072
oracle soft nproc    131072
oracle hard nproc    131072
oracle soft core     unlimited
oracle hard core     unlimited
oracle soft memlock  98728941
oracle hard memlock  98728941
oracle soft stack    10240
oracle hard stack    32768
EOF
chmod 0644 "${limits_file}"

log_section "创建 ORACLE_HOME / ORADATA 目录"
mkdir -p "${DB_BASE}" "${DB_HOME}" /u02/oradata
chown -R oracle:oinstall /u01/app /u02/oradata
chmod -R u+rwX,g+rwX     /u01 /u02

log_section "写入 oracle 用户配置文件"
host="$(hostname -s)"
case "${host}" in
  "${NODE1_HOSTNAME}"|"${NODE2_HOSTNAME}")
    cat > /home/oracle/.bash_profile <<EOF
# .bash_profile — managed by Vagrant provisioner
[ -f /etc/profile ] && . /etc/profile
[ -f ~/.bashrc ] && . ~/.bashrc

export ORACLE_BASE='${DB_BASE}'
export ORACLE_HOME='${DB_HOME}'
export ORACLE_SID='${DB_NAME}'
export PATH="\${ORACLE_HOME}/bin:\${PATH}"
export LD_LIBRARY_PATH="\${ORACLE_HOME}/lib:\${LD_LIBRARY_PATH:-}"
EOF
    chown oracle:oinstall /home/oracle/.bash_profile
    chmod 0644 /home/oracle/.bash_profile
    ;;
  *)
    log_error "主机名 '${host}' 既不是主库也不是备库，拒绝写入 profile"
    exit 1
    ;;
esac
