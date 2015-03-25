# /packages/intranet-translation/www/matrix/new.tcl

ad_page_contract {
    Purpose: form to add a new matrix or edit an existing one

    @author frank.bergmann@matrix-open.com
} {
    object_id:integer
    return_url:optional
}

set user_id [ad_maybe_redirect_for_registration]

# expect commands such as: "im_project_permissions" ...
#
set object_type [db_string acs_object_type "select object_type from acs_objects where object_id=:object_id"]
set perm_cmd "${object_type}_permissions \$user_id \$object_id view read write admin"
eval $perm_cmd

if {!$read} {
    ad_return_complaint 1 "[_ intranet-translation.lt_You_have_no_rights_to_1]"
    return
}

set export_vars [export_form_vars object_id return_url]

# Get match100, match95, ...
set object_name [db_string object_name "select im_name_from_id(:object_id) from dual" -default ""]
foreach trans_task_type [list trans edit proof] {

    array set default [im_trans_trados_matrix -task_type $trans_task_type $object_id]
    set ${trans_task_type}_match0 $default(0)
    set ${trans_task_type}_match50 $default(50)
    set ${trans_task_type}_match75 $default(75)
    set ${trans_task_type}_match85 $default(85)
    set ${trans_task_type}_match95 $default(95)
    set ${trans_task_type}_match100 $default(100)
    set ${trans_task_type}_match_rep $default(rep)
    set ${trans_task_type}_match_x $default(x)
    
    set ${trans_task_type}_match_perf $default(perf)
    set ${trans_task_type}_match_cfr $default(cfr)
    
    set ${trans_task_type}_match_f50 $default(f50)
    set ${trans_task_type}_match_f75 $default(f75)
    set ${trans_task_type}_match_f85 $default(f85)
    set ${trans_task_type}_match_f95 $default(f95)
    
    set ${trans_task_type}_locked $default(locked)

}

set page_title "[_ intranet-translation.lt_Edit_Trados_Matrix_of]"
set page_title "[_ intranet-translation.lt_New_Trados_Matrix_of_]"
set context_bar [im_context_bar $page_title]
set focus {}

