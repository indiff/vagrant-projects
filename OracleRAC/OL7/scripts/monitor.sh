#!/bin/bash
. /vagrant/config/setup.env
while true; do
  echo "==== [$(date)] Disk Usage ===="
  df -h /u01
  echo "==== Directory Changes (/u01) ===="
  ls -l /u01
  echo "==== Network Status ===="
  ip addr
  netstat -tnp | grep LISTEN
  sleep 5
done
