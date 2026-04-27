#!/usr/bin/env bash
#------------------------------------------------------------------------------
# LICENSE UPL 1.0
# Copyright (c) 1982-2026 Oracle and/or its affiliates. All rights reserved.
#
# primary_DB_setup.sh
#   Creates the primary database via dbca, enables archivelog + force
#   logging + flashback, adds standby redo logs, starts DG broker.
#   Runs as the oracle user.
#------------------------------------------------------------------------------
. /vagrant/scripts/_common.sh

if [[ "$(id -un)" != "oracle" ]]; then
  log_error "this script must run as the oracle user"
  exit 1
fi

require_var DB_HOME
require_var DB_NAME
require_var SYS_PASSWORD
require_var CDB
require_var NODE1_HOSTNAME

# sqlplus / as sysdba uses OS auth — no passwords on the command line.
sqlplus_sysdba() {
  "${DB_HOME}/bin/sqlplus" -s -L / as sysdba
}

log_section "Creating primary database with dbca"
dbca_args=(
  -silent -createDatabase
  -templateName General_Purpose.dbc
  -gdbname "${DB_NAME}"
  -sid     "${DB_NAME}"
  -responseFile NO_VALUE
  -characterSet AL32UTF8
  -sysPassword    "${SYS_PASSWORD}"
  -systemPassword "${SYS_PASSWORD}"
  -databaseType   MULTIPURPOSE
  -automaticMemoryManagement false
  -totalMemory 4196
  -storageType FS
  -datafileDestination /u02/oradata
  -redoLogFileSize 50
  -emConfiguration NONE
  -ignorePreReqs
)

if [[ "${CDB}" == "true" ]]; then
  require_var PDB_NAME
  require_var PDB_PASSWORD
  dbca_args+=(
    -createAsContainerDatabase true
    -numberOfPDBs 1
    -pdbName          "${PDB_NAME}"
    -pdbAdminPassword "${PDB_PASSWORD}"
  )
else
  dbca_args+=( -createAsContainerDatabase false )
fi

"${DB_HOME}/bin/dbca" "${dbca_args[@]}"

log_section "Configuring db_create_file_dest + local_listener + FRA"
sqlplus_sysdba <<EOF
WHENEVER SQLERROR EXIT FAILURE
ALTER SYSTEM SET db_create_file_dest='/u02/oradata' SCOPE=BOTH;
ALTER SYSTEM SET db_create_online_log_dest_1='/u02/oradata' SCOPE=BOTH;
ALTER SYSTEM SET local_listener='(ADDRESS=(PROTOCOL=TCP)(HOST=${NODE1_HOSTNAME})(PORT=1521))' SCOPE=BOTH;
ALTER SYSTEM SET db_recovery_file_dest_size=20G SCOPE=BOTH;
ALTER SYSTEM SET db_recovery_file_dest='/u01/app/oracle' SCOPE=BOTH;
exit;
EOF

log_section "Enabling archivelog, force logging, standby redo, flashback"
sqlplus_sysdba <<EOF
WHENEVER SQLERROR EXIT FAILURE
SHUTDOWN IMMEDIATE;
STARTUP MOUNT;
ALTER DATABASE ARCHIVELOG;
ALTER DATABASE OPEN;

ALTER DATABASE FORCE LOGGING;
ALTER SYSTEM SWITCH LOGFILE;

ALTER DATABASE ADD STANDBY LOGFILE SIZE 50M;
ALTER DATABASE ADD STANDBY LOGFILE SIZE 50M;
ALTER DATABASE ADD STANDBY LOGFILE SIZE 50M;
ALTER DATABASE ADD STANDBY LOGFILE SIZE 50M;

ALTER DATABASE FLASHBACK ON;

ALTER SYSTEM SET STANDBY_FILE_MANAGEMENT=AUTO SCOPE=BOTH;
exit;
EOF

log_section "Enabling Data Guard broker"
sqlplus_sysdba <<'EOF'
WHENEVER SQLERROR EXIT FAILURE
ALTER SYSTEM SET dg_broker_start=TRUE SCOPE=BOTH;
exit;
EOF

log_success "Primary DB setup complete"
