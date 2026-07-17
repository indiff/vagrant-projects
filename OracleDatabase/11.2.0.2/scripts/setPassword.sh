#!/bin/bash

# 中文说明：
# 用于统一修改数据库账户口令；较新版本还会遍历已打开的 PDB。

ORACLE_PWD=$1

su -p oracle -c "# 中文：先统一修改 SYS / SYSTEM 账户密码。
sqlplus / as sysdba << EOF
      ALTER USER SYS IDENTIFIED BY "$ORACLE_PWD";
      ALTER USER SYSTEM IDENTIFIED BY "$ORACLE_PWD";
      exit;
EOF"

