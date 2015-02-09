-- upgrade-4.1.0.0.0-4.1.0.0.1.sql

SELECT acs_log__debug('/packages/intranet-translation/sql/postgresql/upgrade/upgrade-4.1.0.0.0-4.1.0.0.1.sql','');

create or replace function inline_0 ()
returns integer as $body$
declare
        v_plugin_id integer;
begin
        -- Locked
    select coalesce(plugin_id,0) into v_plugin_id from im_component_plugins
    where component_tcl = 'im_translation_task_ajax_component';
    
    IF v_plugin_id > 0 THEN
        perform im_component_plugin__delete(v_plugin_id);
    END IF;

    return 0;

end;$body$ language 'plpgsql';
select inline_0 ();
drop function inline_0 ();

select im_component_plugin__new (
        null,                                   	-- plugin_id
        'acs_object',                           	-- object_type
        now(),                                  	-- creation_date
        null,                                   	-- creation_user
        null,                                   	-- creattion_ip
        null,                                   	-- context_id

        'Translation Tasks',      		-- plugin_name
        'intranet-translation', 			-- package_name
        'top',        	                        	-- location
        '/intranet-translation/trans-tasks/task-list',  -- page_url
        null,                                   	-- view_name
        10,                                     	-- sort_order
        'im_task_component $user_id $project_id $return_url'
);

select im_component_plugin__new (
        null,                                   	-- plugin_id
        'acs_object',                           	-- object_type
        now(),                                  	-- creation_date
        null,                                   	-- creation_user
        null,                                   	-- creattion_ip
        null,                                   	-- context_id
        'New Tasks',      		-- plugin_name
        'intranet-translation', 			-- package_name
        'left',        	                        	-- location
        '/intranet-translation/trans-tasks/task-list',  -- page_url
        null,                                   	-- view_name
        10,                                     	-- sort_order
        'im_new_task_component $user_id $project_id $return_url'
);

SELECT acs_permission__grant_permission(
        (select plugin_id from im_component_plugins where plugin_name = 'Translation Tasks' and package_name = 'intranet-translation'),
        (select group_id from groups where group_name = 'Employees'),
        'read'
);

SELECT acs_permission__grant_permission(
        (select plugin_id from im_component_plugins where plugin_name = 'New Tasks' and package_name = 'intranet-translation'),
        (select group_id from groups where group_name = 'Employees'),
        'read'
);