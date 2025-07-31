BEGIN
    dbms_scheduler.disable('ORACLE_OCM.MGMT_CONFIG_JOB');
    dbms_scheduler.disable('ORACLE_OCM.MGMT_STATS_CONFIG_JOB');
END;
/