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
    freelance_ids
        
    trans_price:array
    edit_price:array
    proof_price:array
    other_price:array
    trans_uom:array
    edit_uom:array
    proof_uom:array
    other_uom:array
}

# Get the freelancers

foreach freelance_id $freelance_ids {
    foreach type [list trans edit proof other] {
        set task_type_id [im_project_type_${type}] 
        set uom_id [set ${type}_uom($freelance_id)]
        set price [set ${type}_price($freelance_id)]
        if {$uom_id ne "" && $price ne "" && $task_type_id ne "" } {
            set rates(${task_type_id}_${uom_id}_${freelance_id}) $price
        }
    }    
}

im_translation_create_purchase_orders -project_id $project_id -rate_array rates

db_release_unused_handles
ad_returnredirect $return_url

