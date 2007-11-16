-- upgrade-3.3.1.0.0-3.3.1.1.0.sql


-- Allow translation tasks to be checked/unchecked all together

delete from im_view_columns where column_id = 9021;

insert into im_view_columns (
	column_id, view_id, group_id, column_name, 
	column_render_tcl, extra_select, extra_where, 
	sort_order, visible_for
) values (
	9021,90,NULL,
	'<input type=checkbox name=_dummy onclick=\\"acs_ListCheckAll(''task'',this.checked)\\">',
	'$del_checkbox','','',
	21,'expr $project_write'
);




-- insert into im_view_columns (
-- 	column_id, view_id, group_id, column_name, 
-- 	column_render_tcl, extra_select, extra_where, 
-- 	sort_order, visible_for
-- ) values (
-- 	9021,90,NULL,'[im_gif delete "Delete the Task"]',
-- 	'$del_checkbox','','',
-- 	21,'expr $project_write'
-- );

