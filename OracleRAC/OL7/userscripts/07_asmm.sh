su - grid sqlplus / as sysasm <<EOF
create pfile='/home/grid/asm_pfile.ora' from   spfile;
alter system set sga_max_size=3072M   scope=spfile sid='*';
alter system set sga_target=3072M scope=spfile   sid='*';
alter system set pga_aggregate_target=1024M   scope=spfile sid='*';
alter system set memory_target=0 scope=spfile   sid='*';
alter system set memory_max_target=0   scope=spfile sid='*';
alter system reset memory_max_target   scope=spfile sid='*';
alter system set processes=2000 scope=spfile   sid='*';
EOF
