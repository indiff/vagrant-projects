#!/usr/bin/env bash
#------------------------------------------------------------------------------
# LICENSE UPL 1.0
# Copyright (c) 1982-2026 Oracle and/or its affiliates. All rights reserved.
#
# 08_setup_autostart.sh
#   Install start/stop scripts + systemd unit for the database.
#------------------------------------------------------------------------------
. /vagrant/scripts/_common.sh
require_root
require_var DB_NAME
require_var DB_HOME

log_section "Installing oracle dbstart/dbshut helper scripts"
install -d -o oracle -g oinstall -m 0755 /home/oracle/scripts

cat > /home/oracle/scripts/start_all.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
. /home/oracle/.bash_profile
export ORAENV_ASK=NO
. oraenv
export ORAENV_ASK=YES
dbstart "${ORACLE_HOME}"
EOF

cat > /home/oracle/scripts/stop_all.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
. /home/oracle/.bash_profile
export ORAENV_ASK=NO
. oraenv
export ORAENV_ASK=YES
dbshut "${ORACLE_HOME}"
EOF

chown oracle:oinstall /home/oracle/scripts/start_all.sh /home/oracle/scripts/stop_all.sh
chmod 0755             /home/oracle/scripts/start_all.sh /home/oracle/scripts/stop_all.sh

log_section "Writing /etc/systemd/system/dbora.service"
cat > /etc/systemd/system/dbora.service <<EOF
[Unit]
Description=Oracle Database Service
After=syslog.target network-online.target
Wants=network-online.target

[Service]
# systemd ignores PAM limits — set explicitly.
LimitMEMLOCK=infinity
LimitNOFILE=65535
Type=oneshot
RemainAfterExit=yes
User=oracle
Group=oinstall
Restart=no
ExecStart=/home/oracle/scripts/start_all.sh
ExecStop=/home/oracle/scripts/stop_all.sh

[Install]
WantedBy=multi-user.target
EOF
chmod 0644 /etc/systemd/system/dbora.service

log_section "Writing /etc/oratab"
cat > /etc/oratab <<EOF
${DB_NAME}:${DB_HOME}:Y
EOF
chown oracle:oinstall /etc/oratab
chmod 0664             /etc/oratab

log_section "Enabling dbora.service"
systemctl daemon-reload
systemctl enable dbora.service >/dev/null
