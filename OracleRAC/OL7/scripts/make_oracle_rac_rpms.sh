#!/bin/bash
. /vagrant/config/setup.env
rm -rf /tmp/oracle_rac_rpms
mkdir -p /tmp/oracle_rac_rpms
yumdownloader --resolve --destdir=/tmp/oracle_rac_rpms \
deltarpm expect tree unzip zip oracle-database-preinstall-19c oracleasm-support bc binutils compat-libcap1 compat-libstdc++-33 compat-libstdc++-33.i686 fontconfig-devel glibc.i686 glibc glibc-devel.i686 glibc-devel ksh libaio.i686 libaio libaio-devel.i686 libaio-devel libX11.i686 libX11 libXau.i686 libXau libXi.i686 libXi libXtst.i686 libXtst libgcc.i686 libgcc librdmacm-devel libstdc++.i686 libstdc++ libstdc++-devel.i686 libstdc++-devel libxcb.i686 libxcb make nfs-utils net-tools python python-configshell python-rtslib python-six smartmontools sysstat targetcli unixODBC chrony policycoreutils-python readline rlwrap
cd /tmp/oracle_rac_rpms
cp unzip*.rpm /vagrant/ORCL_software/
zip -r -q -9 /vagrant/ORCL_software/oracle_rac_rpms.zip .
