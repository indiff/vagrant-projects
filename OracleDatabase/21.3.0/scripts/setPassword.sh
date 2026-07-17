#!/bin/bash
#
# Copyright (c) 2023 Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at
# https://oss.oracle.com/licenses/upl.
#
# Since: November, 2016
# Author: gerald.venzl@oracle.com
# Description: Sets the password for sys, system and pdbadmin
#
# DO NOT ALTER OR REMOVE COPYRIGHT NOTICES OR THIS HEADER.
#

# Abort on any error
# 中文说明：
# 用于统一修改数据库账户口令；较新版本还会遍历已打开的 PDB。

set -Eeuo pipefail

ORACLE_PWD=$1

# 中文：先统一修改 SYS / SYSTEM 账户密码。
sqlplus / as sysdba << EOF
  ALTER USER SYS IDENTIFIED BY "$ORACLE_PWD";
  ALTER USER SYSTEM IDENTIFIED BY "$ORACLE_PWD";
EOF

echo '正在为已打开的 PDB 设置 PDBADMIN 密码'

set_pdbadmin_pw=$(mktemp)
trap 'rm -f "${set_pdbadmin_pw}"' EXIT

# 中文：为所有已打开的 PDB 动态生成并执行改密语句。
sqlplus -s / as sysdba > "${set_pdbadmin_pw}" << EOF
  SET HEADING OFF LINESIZE 120 PAGESIZE 0
  SELECT   'ALTER SESSION SET CONTAINER = ' || name || ';' || CHR(10)
        || 'SET SERVEROUTPUT ON' || CHR(10)
        || 'BEGIN' || CHR(10)
        || '  EXECUTE IMMEDIATE ''ALTER USER PDBADMIN IDENTIFIED BY "$ORACLE_PWD"'';' || CHR(10)
        || '  DBMS_OUTPUT.PUT_LINE (''Set PDBADMIN password in ' || name || ' PDB'');' || CHR(10)
        || 'EXCEPTION' || CHR(10)
        || '  WHEN OTHERS THEN' || CHR(10)
        || '    IF SQLCODE = -1918 THEN' || CHR(10)
        || '      DBMS_OUTPUT.PUT_LINE (''PDBADMIN user not found in ' || name || ' PDB'');' || CHR(10)
        || '    ELSE' || CHR(10)
        || '      RAISE;' || CHR(10)
        || '    END IF;' || CHR(10)
        || 'END;' || CHR(10)
        || '/'
  FROM     v\$pdbs
  WHERE    open_mode = 'READ WRITE'
  ORDER BY name;
EOF

sed -i -e 's|no rows selected|PROMPT No open PDBs found|' "${set_pdbadmin_pw}"

echo 'EXIT' | sqlplus -s / as sysdba @"${set_pdbadmin_pw}"

echo '已完成为已打开的 PDB 设置 PDBADMIN 密码'
