-- upgrade-4.1.0.0.0-4.1.0.0.1.sql

SELECT acs_log__debug('/packages/intranet-translation/sql/postgresql/upgrade/upgrade-4.1.0.0.1-4.1.0.0.2.sql','');


CREATE OR REPLACE FUNCTION inline_0 ()
RETURNS INTEGER AS
$$
declare
    v_count integer;
begin
    select count(*) into v_count
    from         user_tab_columns
where lower(table_name) = 'im_trans_trados_matrix'
and lower(column_name) = 'task_type';
    IF 0 != v_count THEN return 0; END IF;
    
    CREATE TYPE trans_task_type AS ENUM ('trans', 'edit', 'proof');

    alter table im_trans_trados_matrix add column task_type trans_task_type;
    update im_trans_trados_matrix set task_type = 'trans';
    return 1;

end;
$$ LANGUAGE 'plpgsql';

SELECT inline_0 ();
DROP FUNCTION inline_0 ();

alter table im_trans_trados_matrix drop constraint im_trans_matrix_pk;
alter table im_trans_trados_matrix add primary key (object_id,task_type);

delete from im_trans_trados_matrix where task_type = 'edit';
insert into im_trans_trados_matrix (object_id,match_x,match_rep,match100,match95,match85,match75,match50,match0,match_perf,match_cfr,match_f95,match_f85,match_f75,match_f50,match_lock,locked,task_type)
select object_id,match_x,match_rep,match100,match95,match85,match75,match50,match0,match_perf,match_cfr,match_f95,match_f85,match_f75,match_f50,match_lock,locked,'edit' from im_trans_trados_matrix where task_type = 'trans';

delete from im_trans_trados_matrix where task_type = 'proof';
insert into im_trans_trados_matrix (object_id,match_x,match_rep,match100,match95,match85,match75,match50,match0,match_perf,match_cfr,match_f95,match_f85,match_f75,match_f50,match_lock,locked,task_type)
select object_id,match_x,match_rep,match100,match95,match85,match75,match50,match0,match_perf,match_cfr,match_f95,match_f85,match_f75,match_f50,match_lock,locked,'proof' from im_trans_trados_matrix where task_type = 'trans';