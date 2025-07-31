su - oracle rman target / <<EOF
configure retention policy to recovery window   of xx days;
configure controlfile autobackup on;
configure backup optimization on;
configure snapshot controlfile name to '+ARCH/snapcf_hxdb.f';
EOF