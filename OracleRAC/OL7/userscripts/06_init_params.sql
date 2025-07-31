-- 查询隐含参数
set linesize 210
col "Parameter" format a30
col "Session Value" format a20
col "Instance Value" format a20
col "Desc" format a70
select a.ksppinm "Parameter",   c.ksppstvl "Instance Value", ksppdesc "Desc"
from sys.x$ksppi a, sys.x$ksppcv b,   sys.x$ksppsv c
where a.indx = b.indx
and a.indx = c.indx
and substr(a.ksppinm, 1, 1) = '_' and a.ksppinm   like '_PX%';

-- 修改参数基线

create pfile='/home/oracle/hxdb_pfile.ora' from   spfile;

alter system set "_ash_size"=254M   scope=spfile;

alter system set   "_cleanup_rollback_entries"=2000 scope=spfile;

alter system set   "_cursor_obsolete_threshold"=1024 scope=spfile;

alter system set   "_clusterwide_global_transactions"=FALSE scope=spfile;

alter system set "_datafile_write_errors_crash_instance"=FALSE   scope=spfile;

alter system set   "_drop_stat_segment"=1 scope=spfile sid='*';

alter system set "_lm_drm_disable"=5   scope=spfile;

alter system set   "_log_segment_dump_parameter"=FALSE scope=spfile;

alter system set "_log_segment_dump_patch"=FALSE   scope=spfile;

alter system set   "_rollback_segment_count"=500 scope=spfile;

alter system set   "_securefiles_concurrency_estimate"=50 scope=spfile;

alter system set "_sys_logon_delay"=0   scope=spfile;

alter system set   "_autotask_max_window"=23040 scope=spfile;

alter system set   "_partition_large_extents"=FALSE scope=spfile;

alter system set   "_use_adaptive_log_file_sync"=FALSE scope=spfile;

--- alter system set   optimizer_adaptive_plans=FALSE scope=spfile;

alter system set audit_sys_operations=FALSE scope=spfile;

alter system set enable_ddl_logging=TRUE   scope=spfile;

alter system set fast_start_mttr_target=300   scope=spfile;

alter system set max_dump_file_size='2048M'   scope=spfile;

alter system set open_links=10 scope=spfile;

alter system set open_links_per_instance=10   scope=spfile;

alter system set   parallel_execution_message_size=32768 scope=spfile;

alter system set recovery_parallelism=8   scope=spfile;

alter system set undo_retention=10800   scope=spfile;

alter system set control_file_record_keep_time=31   scope=spfile;

alter system set db_files=2000 scope=spfile;

alter system set parallel_min_servers=8   scope=spfile;

alter system set event='28401 trace name   context forever,level 1','10949 trace name context forever,level 1' scope=spfile;

--10949（12c）：Bug 18498878 - medium size tables do not cached consistently (文档 ID 18498878.8)

--28401：High   'library cache lock' Wait Time Due to Invalid Login Attempts (文档 ID 1309738.1)

-- 下面参数根据实际内存情况设置

alter system set sga_max_size=30G scope=spfile;

alter system set shared_pool_size=6G   scope=spfile;

alter system set java_pool_size=1G   scope=spfile;

alter system set large_pool_size=1G   scope=spfile;

-- 下面参数根据cpu count设置

col cpu_count new_value cpu_count noprint;

select case when ceil(value/2) < 16 then 16

else ceil(value/2)

end cpu_count

from v$parameter where name='cpu_count';

alter system set   parallel_max_servers=&cpu_count scope=spfile;

alter system set job_queue_processes=&cpu_count   scope=spfile;

-- 禁用inmemory
alter system set inmemory_query=DISABLE   scope=spfile;