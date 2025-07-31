--查看当前自动任务窗口

--数据库自带的自动任务作业窗口开启时间为：工作日22点到凌晨两点、周末22点到第二天18点

set lines 222 pages 999
col WINDOW_NAME for a20
col REPEAT_INTERVAL for a70
col DURATION for a15
select window_name,repeat_interval,duration,enabled   from dba_scheduler_windows;

-- 查看当前自动任务窗口

-- 调整窗口期为每天的 2 点至6  点，2 是   2 点开始的意思，240 是持续 240 分钟（4 小时）

BEGIN
    dbms_scheduler.set_attribute(name=>'SYS.MONDAY_WINDOW',attribute=>'REPEAT_INTERVAL',value=>'freq=daily;byday=MON;byhour=2;byminute=0;bysecond=0');
    dbms_scheduler.set_attribute(name=>'SYS.TUESDAY_WINDOW',attribute=>'REPEAT_INTERVAL',value=>'freq=daily;byday=TUE;byhour=2;byminute=0;bysecond=0');
    dbms_scheduler.set_attribute(name=>'SYS.WEDNESDAY_WINDOW',attribute=>'REPEAT_INTERVAL',value=>'freq=daily;byday=WED;byhour=2;byminute=0;bysecond=0');
    dbms_scheduler.set_attribute(name=>'SYS.THURSDAY_WINDOW',attribute=>'REPEAT_INTERVAL',value=>'freq=daily;byday=THU;byhour=2;byminute=0;bysecond=0');
    dbms_scheduler.set_attribute(name=>'SYS.FRIDAY_WINDOW',attribute=>'REPEAT_INTERVAL',value=>'freq=daily;byday=FRI;byhour=2;byminute=0;bysecond=0');
    dbms_scheduler.set_attribute(name=>'SYS.SATURDAY_WINDOW',attribute=>'REPEAT_INTERVAL',value=>'freq=daily;byday=SAT;byhour=2;byminute=0;bysecond=0');
    dbms_scheduler.set_attribute(name=>'SYS.SUNDAY_WINDOW',attribute=>'REPEAT_INTERVAL',value=>'freq=daily;byday=SUN;byhour=2;byminute=0;bysecond=0');
    dbms_scheduler.set_attribute(name=>'SYS.MONDAY_WINDOW',attribute=>'DURATION',value=>numtodsinterval(240,   'minute'));
    dbms_scheduler.set_attribute(name=>'SYS.TUESDAY_WINDOW',attribute=>'DURATION',value=>numtodsinterval(240,   'minute'));
    dbms_scheduler.set_attribute(name=>'SYS.WEDNESDAY_WINDOW',attribute=>'DURATION',value=>numtodsinterval(240,   'minute'));
    dbms_scheduler.set_attribute(name=>'SYS.THURSDAY_WINDOW',attribute=>'DURATION',value=>numtodsinterval(240,   'minute'));
    dbms_scheduler.set_attribute(name=>'SYS.FRIDAY_WINDOW',attribute=>'DURATION',value=>numtodsinterval(240,   'minute'));
    dbms_scheduler.set_attribute(name=>'SYS.SATURDAY_WINDOW',attribute=>'DURATION',value=>numtodsinterval(240,   'minute'));
    dbms_scheduler.set_attribute(name=>'SYS.SUNDAY_WINDOW',attribute=>'DURATION',value=>numtodsinterval(240,   'minute'));
END;
/