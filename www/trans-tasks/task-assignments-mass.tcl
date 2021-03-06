# /packages/intranet-translation/www/trans-tasks/task-assignments-mass.tcl
#
# Copyright (C) 2003 - 2009 ]project-open[
#
# All rights reserved. Please check
# http://www.project-open.com/license/ for details.

ad_page_contract {
    Purpose: Takes commands from the /intranet/projects/view
    page and saves changes, deletes tasks and scans for Trados
    files.

    @param return_url the url to return to
    @param project_id group id
} {
    return_url
    project_id:integer
    target_language_ids 
    
    task_type_list
    trans_mass:array
    edit_mass:array
    proof_mass:array
    other_mass:array
    trans_end_date:array
    proof_end_date:array
    edit_end_date:array
    other_end_date:array
    bulk_file_ids:multiple
}

array set task_types $task_type_list
set user_id [ad_maybe_redirect_for_registration]

foreach target_language_id $target_language_ids {
    set task_ids [db_list task_ids "select task_id from im_trans_tasks where target_language_id = :target_language_id and project_id = :project_id and task_name in (select task_name from im_trans_tasks where task_id in ([template::util::tcl_to_sql_list $bulk_file_ids]))"]   
    
    ds_comment "$target_language_id :: $task_ids"
    foreach task_id $task_ids {
    
        set update_sql_list [list]    
        foreach type [list trans edit proof other] {
            if {[lsearch $task_types($task_id) $type]>-1} {
                set $type [set ${type}_mass($target_language_id)]
                if {[set $type] ne "no_change"} {
                    lappend update_sql_list "${type}_id = :$type"
                    set ${type}_end_date_target [set ${type}_end_date($target_language_id)]
                    if {[set ${type}_end_date_target] ne ""} {
                        lappend update_sql_list "${type}_end_date = :${type}_end_date_target"
                    }
                }
            }
        }

        if {[llength $update_sql_list]>0} {
            set task_workflow_update_sql "
                update im_trans_tasks set
                [join $update_sql_list ","]
                where
                task_id = :task_id
        "
            db_dml update_workflow $task_workflow_update_sql
        }
        # Notify system about the joyful act
        im_user_exit_call trans_task_assign $task_id
        im_audit -object_type "im_trans_task" -action after_update -object_id $task_id
    }
}

db_release_unused_handles
ad_returnredirect $return_url

