# /packages/intranet-translatin/www/matrix/new-2
#
# Copyright (C) 1998-2004 various parties
# The software is based on ArsDigita ACS 3.4
#
# This program is free software. You can redistribute it
# and/or modify it under the terms of the GNU General
# Public License as published by the Free Software Foundation;
# either version 2 of the License, or (at your option)
# any later version. This program is distributed in the
# hope that it will be useful, but WITHOUT ANY WARRANTY;
# without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.
# See the GNU General Public License for more details.

ad_page_contract {
    Purpose: verifies and stores project information to db.

    @author mbryzek@arsdigita.com
    @author Frank Bergmann (frank.bergmann@project-open.com)
    @author Malte Sussdorff ( malte.sussdorff@cognovis.de )
} {
    return_url:optional
    object_id:integer
    trans_match_x:float
    trans_match_rep:float
    trans_match100:float
    trans_match95:float
    trans_match85:float
    trans_match75:float
    trans_match50:float
    trans_match0:float

    trans_match_perf:float
    trans_match_cfr:float
    trans_match_f95:float
    trans_match_f85:float
    trans_match_f75:float
    trans_match_f50:float

    trans_locked:float

    edit_match_x:float
    edit_match_rep:float
    edit_match100:float
    edit_match95:float
    edit_match85:float
    edit_match75:float
    edit_match50:float
    edit_match0:float
    
    edit_match_perf:float
    edit_match_cfr:float
    edit_match_f95:float
    edit_match_f85:float
    edit_match_f75:float
    edit_match_f50:float
    
    edit_locked:float
    
    proof_match_x:float
    proof_match_rep:float
    proof_match100:float
    proof_match95:float
    proof_match85:float
    proof_match75:float
    proof_match50:float
    proof_match0:float
    
    proof_match_perf:float
    proof_match_cfr:float
    proof_match_f95:float
    proof_match_f85:float
    proof_match_f75:float
    proof_match_f50:float
    
    proof_locked:float
}

# -----------------------------------------------------------------
# Defaults & Security
# -----------------------------------------------------------------

set user_id [ad_maybe_redirect_for_registration]


# expect commands such as: "im_project_permissions" ...
#
set object_type [db_string acs_object_type "select object_type from acs_objects where object_id=:object_id"]
set perm_cmd "${object_type}_permissions \$user_id \$object_id view read write admin"
eval $perm_cmd

if {!$write} {
    ad_return_complaint 1 "[_ intranet-translation.lt_You_have_no_rights_to]"
    return
}

# -----------------------------------------------------------------
# Update the object
# -----------------------------------------------------------------

foreach trans_task_type {trans edit proof} {
    set count [db_string matrix_count "select count(*) from im_trans_trados_matrix where object_id=:object_id and task_type=:trans_task_type"]
    ds_comment "$trans_task_type ::: [set ${trans_task_type}_locked]"
    if {!$count} {
        db_dml insert_matrix "
    insert into im_trans_trados_matrix 
    (object_id, match_x, match_rep, match100, match95, match85, match75, match50, match0, task_type) values
    (:object_id, :${trans_task_type}_match_x, :${trans_task_type}_match_rep, :${trans_task_type}_match100, :${trans_task_type}_match95, :${trans_task_type}_match85, :${trans_task_type}_match75, :${trans_task_type}_match50, :${trans_task_type}_match0, :trans_task_type)"
    }
    
    db_dml update_matrix "
    update im_trans_trados_matrix set
    	match_x = :${trans_task_type}_match_x,
    	match_rep = :${trans_task_type}_match_rep,
    	match100 = :${trans_task_type}_match100,
    	match95 = :${trans_task_type}_match95,
    	match85 = :${trans_task_type}_match85,
    	match75 = :${trans_task_type}_match75,
    	match50 = :${trans_task_type}_match50,
    	match0 = :${trans_task_type}_match0,
    	match_perf = :${trans_task_type}_match_perf,
    	match_cfr = :${trans_task_type}_match_cfr,
    	match_f95 = :${trans_task_type}_match_f95,
    	match_f85 = :${trans_task_type}_match_f85,
    	match_f75 = :${trans_task_type}_match_f75,
    	match_f50 = :${trans_task_type}_match_f50,
    	locked = :${trans_task_type}_locked
    where
    	object_id = :object_id
    	and task_type = :trans_task_type
    "
}

ad_returnredirect $return_url
