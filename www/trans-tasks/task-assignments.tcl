# /packages/intranet-translation/www/trans-tasks/task-assignments.tcl
#
# Copyright (C) 2003-2009 ]project-open[
#
# All rights reserved. Please check
# http://www.project-open.com/license/ for details.

ad_page_contract {
    Assign translators, editors and proof readers to every task

    @param project_id the project_id
    @param orderby the display order
    @param show_all_comments whether to show all comments

    @author Guillermo Belcic
    @author frank.bergmann@project-open.com
} {
    project_id:integer
    { return_url "" }
    { orderby "subproject_name" }
    { auto_assigment "" }
    { auto_assigned_words 0 }
    { trans_auto_id 0 }
    { edit_auto_id 0 }
    { proof_auto_id 0 }
    { other_auto_id 0 }
}


# -------------------------------------------------------------------------
# Security & Default
# -------------------------------------------------------------------------

set user_id [ad_maybe_redirect_for_registration]
if {![im_permission $user_id view_trans_proj_detail]} { 
    ad_return_complaint 1 "<li>You don't have sufficient privileges to view this page"
    return
}

set project_nr [db_string project_nr "select project_nr from im_projects where project_id = :project_id" -default ""]
set page_title "$project_nr - [_ intranet-translation.lt_Translation_Assignmen]"
set context_bar [im_context_bar [list /intranet/projects/ "[_ intranet-translation.Projects]"] [list "/intranet/projects/view?project_id=$project_id" "[_ intranet-translation.One_project]"] $page_title]

if {[apm_package_installed_p "intranet-freelance"]} {
    set subject_area_id [db_string subject "select skill_id from im_object_freelance_skill_map where skill_type_id = 2014 and object_id = :project_id limit 1" -default ""]
} else { 
    set subject_area_id [db_string subject "select subject_area_id from im_projects where project_id = :project_id" -default ""]
}

set auto_assignment_component_p [parameter::get_from_package_key -package_key intranet-translation -parameter "EnableAutoAssignmentComponentP" -default 0]
set mass_assignment_component_p [parameter::get_from_package_key -package_key intranet-translation -parameter "EnableMassAssignmentComponentP" -default 0]

# Deal with the dates
foreach type [list trans edit proof other] {
	set ${type}_end_date ""
	set ${type}_end_dates [list]
}

if {"" == $return_url} { set return_url [im_url_with_query] }

set bgcolor(0) " class=roweven"
set bgcolor(1) " class=rowodd"

# Workflow available?
set wf_installed_p [im_workflow_installed_p]

set date_format "YYYY-MM-DD"

# -------------------------------------------------------------------------
# Auto assign
# -------------------------------------------------------------------------

set error 0

# Check that there is only a single role being assigned
set assigned_roles 0
if {$trans_auto_id > 0} { incr assigned_roles }
if {$edit_auto_id > 0} { incr assigned_roles }
if {$proof_auto_id > 0} { incr assigned_roles }
if {$other_auto_id > 0} { incr assigned_roles }
if {$assigned_roles > 1} {
    incr error
    append errors "<LI>[_ intranet-translation.lt_Please_choose_only_a_]"
}

if {$auto_assigned_words > 0 && $assigned_roles == 0} {
    incr error
    append errors "<LI>[_ intranet-translation.lt_You_havent_selected_a]"
}

if { $error > 0 } {
    ad_return_complaint "[_ intranet-translation.Input_Error]" "$errors"
}

# ---------------------------------------------------------------------
# Get the list of available resources and their roles
# to format the drop-down select boxes
# ---------------------------------------------------------------------

set resource_sql "
select
	r.object_id_two as user_id,
	im_name_from_user_id (r.object_id_two) as user_name,
	im_category_from_id(m.object_role_id) as role
from
	acs_rels r,
	im_biz_object_members m
where
	r.object_id_one=:project_id
	and r.rel_id = m.rel_id
"


# Add all users into a list
set project_resource_list [list]
db_foreach resource_select $resource_sql {
    lappend project_resource_list [list $user_id $user_name $role]
}



# ---------------------------------------------------------------------
# Get the list of available groups
# ---------------------------------------------------------------------

set groups_sql "
select
	g.group_id,
	g.group_name,
	0 as role
from
	groups g,
	im_profiles p
where
	g.group_id = p.profile_id
"


# Add all groups into a list
set group_list [list]
db_foreach group_select $groups_sql {
    lappend group_list [list $group_id $group_name $role]
}


# ---------------------------------------------------------------------
# Select and format the list of tasks
# ---------------------------------------------------------------------

set extra_where ""
if {$wf_installed_p} {
    set extra_where "and
	t.task_id not in (
		select	object_id
		from	wf_cases
	)
"
}

set task_sql "
select
	t.*,
	ptype_cat.aux_int1 as aux_task_type_id,
	im_category_from_id(t.task_uom_id) as task_uom,
	im_category_from_id(t.task_type_id) as task_type,
	im_category_from_id(t.task_status_id) as task_status,
	im_category_from_id(t.target_language_id) as target_language,
	im_email_from_user_id (t.trans_id) as trans_email,
	im_name_from_user_id (t.trans_id) as trans_name,
	im_email_from_user_id (t.edit_id) as edit_email,
	im_name_from_user_id (t.edit_id) as edit_name,
	im_email_from_user_id (t.proof_id) as proof_email,
	im_name_from_user_id (t.proof_id) as proof_name,
	im_email_from_user_id (t.other_id) as other_email,
	im_name_from_user_id (t.other_id) as other_name
from
	im_trans_tasks t,
	im_categories ptype_cat
where
	t.project_id=:project_id and
	t.task_status_id <> 372 and
	ptype_cat.category_id = t.task_type_id
	$extra_where
order by
        t.task_name,
        t.target_language_id
"

# ToDo: Remove the DynamicWF tasks


set task_colspan 9
set task_html "
<form method=POST action=task-assignments-2>
[export_form_vars project_id return_url]
	<table border=0>
	  <tr>
	    <td colspan=$task_colspan class=rowtitle align=center>
	      [_ intranet-translation.Task_Assignments]
	    </td>
	  </tr>
	  <tr>
	    <td class=rowtitle align=center>[_ intranet-translation.Task_Name]</td>
	    <td class=rowtitle align=center>[_ intranet-translation.Target_Lang]</td>
	    <td class=rowtitle align=center>[_ intranet-translation.Task_Type]</td>
	    <td class=rowtitle align=center>[_ intranet-translation.Size]</td>
	    <td class=rowtitle align=center>[_ intranet-translation.UoM]</td>
	    <td class=rowtitle align=center>[_ intranet-translation.Trans]</td>
	    <td class=rowtitle align=center>[_ intranet-translation.Edit]</td>
	    <td class=rowtitle align=center>[_ intranet-translation.Proof]</td>
	    <td class=rowtitle align=center>[_ intranet-translation.Other]</td>
	  </tr>
"

# We only need to render an Auto-Assign drop-down box for those
# workflow roles with occur in the project.
# So we define a set of counters for each role, that are evaluated
# later in the Auto-Assign-Component.
#
set n_trans 0
set n_edit 0
set n_proof 0
set n_other 0
set ctr 0

set task_list [array names tasks_id]

# Prepare the list of assignees for each task for later processing

set trans_assignee_ids [list]
set edit_assignee_ids [list]
set proof_assignee_ids [list]
set other_assignee_ids [list]
set uom_ids [list]
set target_language_ids [list]

# Keep a list of unique task_names, so we can select the task_names for mass assignment
# Sadly we have tasks for each language combination already in the system ....
set task_names [list]

db_foreach select_tasks $task_sql {
    #    ns_log Notice "task_id=$task_id, status_id=$task_status_id"

    # Check if the task_type was set in categories
    if {"" != $aux_task_type_id} { set task_type_id $aux_task_type_id }

    # Determine if this task is auto-assignable or not,
    # depending on the unit of measure (UoM). We currently
    # only exclude Units and Days.
    #
    # 320 Hour  
    # 321 Day 
    # 322 Unit 
    # 323 Page 
    # 324 S-Word 
    # 325 T-Word 
    # 326 S-Line 
    # 327 T-Line
    #
    if {320 == $task_uom_id || 323 == $task_uom_id || 324 == $task_uom_id || 325 == $task_uom_id || 326 == $task_uom_id || 327 == $task_uom_id } {
        set auto_assignable_task 1
    } else {
        set auto_assignable_task 0
    }

    # Add the list uom we have in this assignment
    if {[lsearch $uom_ids $task_uom]<0} {lappend uom_ids $task_uom}
    if {[lsearch $target_language_ids $target_language_id]<0} {lappend target_language_ids $target_language_id}
    # Determine the fields necessary for each task type
    set trans 0
    set edit 0
    set proof 0
    set other 0
    set wf_list [db_string wf_list "select aux_string1 from im_categories where category_id = :task_type_id"]
    if {"" == $wf_list} { set wf_list "other" }

	# Set the task types so we know which actions are supposed to be done in this task
	set task_types($task_id) [list]
    foreach wf $wf_list {
        switch $wf {
	        trans { 
                set trans 1 
                incr n_trans
                lappend task_types($task_id) "trans"
            }
            edit { 
                set edit 1 
                incr n_edit
				lappend task_types($task_id) "edit"
            }
            proof { 
                set proof 1 
                incr n_proof
                lappend task_types($task_id) "proof"                
            }
            other { 
                set other 1 
                incr n_other
                lappend task_types($task_id) "other"                
            }
        }
    }

    # introduce spaces after "/" (by "/ ") to allow for graceful rendering
    regsub {/} $task_name "/ " task_name

    append task_html "
	<tr $bgcolor([expr $ctr % 2])>
	<input type=hidden name=task_status_id.$task_id value=$task_status_id>
	<td>$task_name</td>
	<td>$target_language</td>
	<td>$task_type</td>
	<td>$task_units</td>
	<td>$task_uom</td>
	<td>\n"

    # here we compare the assigned words, if the task isn't assigned and if
    # the task's words can be assigned to the translator.:

    # Auto-Assign the task/role if the translator_id is NULL (""),
    # and if there are words left to assign
    if {$auto_assignable_task && $trans_id == "" && $trans_auto_id > 0 && $trans && $auto_assigned_words > $task_units} {
        set trans_id $trans_auto_id
        set auto_assigned_words [expr $auto_assigned_words - $task_units]
    }

    if {$auto_assignable_task && $edit_id == "" && $edit_auto_id > 0 && $edit && $auto_assigned_words > $task_units} {
        set edit_id $edit_auto_id
        set auto_assigned_words [expr $auto_assigned_words - $task_units]
    }

    if {$auto_assignable_task && $proof_id == "" && $proof_auto_id > 0 && $proof && $auto_assigned_words > $task_units} {
        set proof_id $proof_auto_id
        set auto_assigned_words [expr $auto_assigned_words - $task_units]
    }

    if {$auto_assignable_task && $other_id == "" && $other_auto_id > 0 && $other && $auto_assigned_words > $task_units} {
        set other_id $other_auto_id
        set auto_assigned_words [expr $auto_assigned_words - $task_units]
    }

    # Render the 4 possible workflow roles to assign
    
	set orig_source_language_id $source_language_id
    foreach type [list trans edit proof other] {
        set ${type}_html ""
        set this_end_date ""
        if {[set $type]} {
            append ${type}_html [im_task_user_select -source_language_id $source_language_id -target_language_id $target_language_id task_${type}.$task_id $project_resource_list [set ${type}_id] translator]
            set this_end_date [set ${type}_end_date]
            if { $this_end_date eq ""} {
                set this_end_date $end_date
            } 
            
            append ${type}_html "<br><input type=text size=25 maxlength=25 name=${type}_end.$task_id value=\"$this_end_date\">"

            set assignee_id [set ${type}_id]
            if { $assignee_id ne ""} {
                lappend ${type}_assignee_ids $assignee_id
                set ${type}_langs($assignee_id) "${source_language_id}-${target_language_id}"
                
                if {[info exists ${type}-${task_uom}($assignee_id)]} {
                    set ${type}-${task_uom}($assignee_id) [expr $task_units + [set ${type}-${task_uom}($assignee_id)]]
                } else {
                    set ${type}-${task_uom}($assignee_id) $task_units
                }
            }
        } else {
            append ${type}_html "<input type=hidden name='task_${type}.$task_id' value=''><input type=hidden name='${type}_end.$task_id' value=''>"
        }
        
        # Append the end date to the list so we can prefill for the mass selection
        if {$this_end_date ne ""} {
	        lappend ${type}_end_dates $this_end_date
	    }
    }
    
    append task_html "$trans_html</td><td>$edit_html</td><td>$proof_html</td><td>$other_html</td></tr>"
    
    incr ctr    
}

set freelancer_ids [list]
set assignee_ids [concat $trans_assignee_ids $edit_assignee_ids $proof_assignee_ids $other_assignee_ids]

# Find out the list of freelancers in the assignments
foreach freelancer_id [lsort -unique $assignee_ids] {
    if {![im_user_is_employee_p $freelancer_id] && "" != $freelancer_id} {
        lappend freelancer_ids $freelancer_id
    }
}


set price_html ""
if {[llength freelancer_ids]>0 && [apm_package_installed_p "intranet-freelance-invoices"]} {
    # Get the prices for all freelancers
    
    
    # Add the form for the freelancer prices
    
    set price_html "
    <form method=POST action='/intranet-freelance-invoices/create-purchase-orders'>
    [export_form_vars project_id return_url]
    	<table border=0>
    	  <tr>
    	    <td colspan=9 class=rowtitle align=center>
    	      [_ intranet-freelance-invoices.CreatePurchaseOrders]
    	    </td>
    	  </tr>
    	  <tr>
    	    <td class=rowtitle align=center>[_ intranet-core.Assignee]</td>
    	    <td class=rowtitle align=center colspan=2>[_ intranet-translation.Trans]</td>
    	    <td class=rowtitle align=center colspan=2>[_ intranet-translation.Edit]</td>
    	    <td class=rowtitle align=center colspan=2>[_ intranet-translation.Proof]</td>
    	    <td class=rowtitle align=center colspan=2>[_ intranet-translation.Other]</td>
    	  </tr>
    "

    foreach freelancer_id $freelancer_ids {
        append price_html "
            <tr>
    	    <td>[im_name_from_user_id $freelancer_id]</td>
        "
        
        # Check for each of the assignments
        set freelance_company_id [db_string company "select company_id from acs_rels, im_companies where company_id = object_id_one and object_id_two = :freelancer_id" -default [im_company_freelance]]
        
        foreach type [list trans edit proof other] {
            
            # We try to find the correct trans type id. If we have prices maintained though for Trans as well as Trans / Edit, we will most likely not get the proper result, especially not if we have two different Project Types which have 
            # Trans on it's own but are referrenced for the same company.
            set task_type_id [db_string task "select category_id from im_categories where category_id in (select distinct task_type_id from im_trans_prices where company_id = :freelance_company_id) and aux_string1 like '%${type}%' and category_type = 'Intranet Project Type' limit 1" -default ""]
            
            if {$task_type_id eq ""} {
                set freelance_company_id [im_company_freelance]
                set task_type_id [db_string task "select category_id from im_categories where category_id in (select distinct task_type_id from im_trans_prices where company_id = :freelance_company_id) and aux_string1 like '%${type}%' and category_type = 'Intranet Project Type' limit 1" -default ""]
            }
            if {$task_type_id eq ""} {
                set price ""
            } else {
                if {[info exists ${type}_langs($freelancer_id)]} {
                    set langs [split [set ${type}_langs($freelancer_id)] "-"]
                    set source_language_id [lindex $langs 0]
                    set target_language_id [lindex $langs 1]
                } else {
                    set source_language_id ""
                    set target_language_id ""
                }
                db_1row relevant_price "
        		select 
        			im_trans_prices_calc_relevancy (
        				p.company_id, :freelance_company_id,
        				p.task_type_id, :task_type_id,
        				p.subject_area_id, :subject_area_id,
        				p.target_language_id, :target_language_id,
        				p.source_language_id, :source_language_id
        			) as relevancy,
        			p.price
        		from im_trans_prices p
                where company_id = :freelance_company_id
                order by relevancy desc
                limit 1
                "
                ds_comment "$freelance_company_id :: $price :: $relevancy"
            }
            
            if {[lsearch [set ${type}_assignee_ids] $freelancer_id]>-1} {
                set ${type}_uom_ids($freelancer_id) [list]
                foreach uom_id $uom_ids {
                     # Find out of the assignee is assigned to multiple Units of measure
                     if {[info exists ${type}-${uom_id}($freelancer_id)]} {
                         lappend ${type}_uom_ids($freelancer_id) $uom_id
                     }
                }

                switch [llength [set ${type}_uom_ids($freelancer_id)]] {
                    0 {
                        append price_html "<td colspan=2>&nbsp;</td>"                    
                    }
                    1 {
                        set uom_id [set ${type}_uom_ids($freelancer_id)]
                        set units [set ${type}-${uom_id}($freelancer_id)]

                        append price_html "
                            <td align=left>$units [im_category_from_id $uom_id]</td>
                            <td><input type=text size=5 maxlength=5 name=price_${type}_${uom_id}.$freelancer_id value=\"$price\">
                        "                                
                    }
                    default {
                        # Ups, we need to show multiple prices.... 
                        append price_html "<td colspan=2>&nbsp;</td>"                    
                    }
                }
            } else {
                append price_html "<td colspan=2>&nbsp;</td>"                                
            }
        }
        append price_html "</tr>"        
    }
    append price_html "</table></form>"    
}

append task_html "
</table>
<input type=submit value=Submit>
</form>
"

# Don't show component if there are no tasks
if {$wf_installed_p && !$ctr} { set task_html "" }

# -------------------------------------------------------------------
# Extract the Headers
# for each of the different workflows that might occur in 
# the list of tasks of one project
# -------------------------------------------------------------------

# Determine the header fields for each workflow key
# Data Structures:
#	transitions(workflow_key) => [orderd list of transition-name tuples]
#
set wf_header_sql "
	select distinct
	        wfc.workflow_key,
	        wft.transition_key,
		wft.transition_name,
	        wft.sort_order
	from
	        im_trans_tasks t
	        LEFT OUTER JOIN wf_cases wfc ON (t.task_id = wfc.object_id)
	        LEFT OUTER JOIN wf_transitions wft ON (wfc.workflow_key = wft.workflow_key)
	where
	        t.project_id = :project_id
	        and wft.trigger_type not in ('automatic', 'message')
	order by
	        wfc.workflow_key,
	        wft.sort_order
"
db_foreach wf_header $wf_header_sql {
    set trans_key "$workflow_key $transition_key"
    set trans_list [list]
    if {[info exists transitions($workflow_key)]} { 
	set trans_list $transitions($workflow_key) 
    }
    lappend trans_list [list $transition_key $transition_name]
    ns_log Notice "task-assignments: header: wf=$workflow_key, trans=$transition_key: $trans_list"
    set transitions($workflow_key) $trans_list
}


# -------------------------------------------------------------------
# Build the assignments table
# 
# This query extracts all tasks and all of the task assignments and
# stores them in an two-dimensional matrix (implmented as a hash).
# -------------------------------------------------------------------

set wf_assignments_sql "
	select distinct
	        t.task_id,
		wfc.case_id,
	        wfc.workflow_key,
	        wft.transition_key,
	        wft.trigger_type,
	        wft.sort_order,
	        wfca.party_id,
		wfta.deadline,
		to_char(wfta.deadline, :date_format) as deadline_formatted
	from
	        im_trans_tasks t
	        LEFT OUTER JOIN wf_cases wfc ON (t.task_id = wfc.object_id)
	        LEFT OUTER JOIN wf_transitions wft ON (wfc.workflow_key = wft.workflow_key)
		LEFT OUTER JOIN wf_tasks wfta ON (
			wfta.case_id = wfc.case_id
			and wfc.workflow_key = wfta.workflow_key
			and wfta.transition_key = wfta.transition_key
		)
	        LEFT OUTER JOIN wf_case_assignments wfca ON (
	                wfca.case_id = wfc.case_id
			and wfca.role_key = wft.role_key
	        )
	where
	        t.project_id = :project_id
	        and wft.trigger_type not in ('automatic', 'message')
	order by
	        wfc.workflow_key,
	        wft.sort_order
"

db_foreach wf_assignment $wf_assignments_sql {
    set ass_key "$task_id $transition_key"
    set ass($ass_key) $party_id
    set deadl($ass_key) $deadline_formatted

    ns_log Notice "task-assignments: $workflow_key: '$ass_key' -> '$party_id'"
}


# -------------------------------------------------------------------
# Render the assignments table
# -------------------------------------------------------------------

set wf_assignments_render_sql "
	select
		t.*,
		to_char(t.end_date, :date_format) as end_date_formatted,
		wfc.workflow_key,
		im_category_from_id(t.task_uom_id) as task_uom,
		im_category_from_id(t.task_type_id) as task_type,
		im_category_from_id(t.task_status_id) as task_status,
		im_category_from_id(t.target_language_id) as target_language
	from
		im_trans_tasks t,
		wf_cases wfc
	where
		t.project_id = :project_id
		and t.task_id = wfc.object_id
	order by
		wfc.workflow_key,
		t.task_name
"

set ass_html "
<form method=POST action=task-assignments-wf-2>
[export_form_vars project_id return_url]
<table border=0>
"


set ctr 0
set last_workflow_key ""
db_foreach wf_assignment $wf_assignments_render_sql {
    ns_log Notice "task-assignments: ctr=$ctr, wf_key='$workflow_key', task_id=$task_id"

    # Render a new header line for evey type of Workflow
    if {$last_workflow_key != $workflow_key} {
        append ass_html "
	<tr>
	<td class=rowtitle align=center>[_ intranet-translation.Task_Name]</td>
	<td class=rowtitle align=center>[_ intranet-translation.Target_Lang]</td>
	<td class=rowtitle align=center>[_ intranet-translation.Task_Type]</td>
	<td class=rowtitle align=center>[_ intranet-translation.Size]</td>
	<td class=rowtitle align=center>[_ intranet-translation.UoM]</td>\n"

	set transition_list $transitions($workflow_key)
	foreach trans $transition_list {
	    set trans_key [lindex $trans 0]
	    set trans_name [lindex $trans 1]
	    set key "$workflow_key $trans_key"
	    append ass_html "<td class=rowtitle align=center
		>[lang::message::lookup "" intranet-translation.$trans_key $trans_name]</td>\n"
	}
	append ass_html "</tr>\n"
	set last_workflow_key $workflow_key
    }

    append ass_html "
	    <tr $bgcolor([expr $ctr % 2])>
	        <td>
		  $task_name $task_id
		  <input type=hidden name=task_id value=\"$task_id\">
		</td>
	        <td>$target_language</td>
	        <td>$task_type</td>
	        <td><nobr>$task_units</nobr></td>
	        <td><nobr>$task_uom</nobr></td>
    "
    foreach trans $transitions($workflow_key) {

	set trans_key [lindex $trans 0]
	set trans_name [lindex $trans 1]
	set ass_key "$task_id $trans_key"
	set ass_val $ass($ass_key)
	set deadl_val $deadl($ass_key)
	if {"" == $deadl_val} { set deadl_val "$end_date_formatted" }

	append ass_html "<td>\n"
	append ass_html [im_task_user_select -group_list $group_list "assignment.${trans_key}-$task_id" $project_resource_list $ass_val]
	append ass_html "\n"
	append ass_html "<input type=text size=10 name=deadline.${trans_key}-$task_id value=\"$deadl_val\">"
	append ass_html "\n"
    }
    append ass_html "</tr>\n"
    incr ctr
}

append ass_html "
</table>
<input type=submit value=Submit>
</form>
"

# Skip the dynamic workflow component completely if there was
# no dynamic WF task:
#
if {0 == $ctr} { set ass_html "" }


# -------------------------------------------------------------------
# Auto_Assign HTML Component old version
# -------------------------------------------------------------------

set auto_assignment_html_body ""
set auto_assignment_html_header ""

append auto_assignment_html_header "<td class=rowtitle>[_ intranet-translation.Num_Words]</td>\n"
append auto_assignment_html_body "<td><input type=text size=6 name=auto_assigned_words></td>\n"

if { $n_trans > 0 } {
    append auto_assignment_html_header "<td class=rowtitle>[_ intranet-translation.Trans]</td>\n"
    append auto_assignment_html_body "<td>[im_task_user_select trans_auto_id $project_resource_list "" translator]</td>\n"
}
if { $n_edit > 0 } {
    append auto_assignment_html_header "<td class=rowtitle>[_ intranet-translation.Edit]</td>\n"
    append auto_assignment_html_body "<td>[im_task_user_select edit_auto_id $project_resource_list "" editor]</td>\n"
}
if { $n_proof > 0} {
    append auto_assignment_html_header "<td class=rowtitle>[_ intranet-translation.Proof]</td>\n"
    append auto_assignment_html_body "<td>[im_task_user_select proof_auto_id $project_resource_list "" proof]</td>\n"
}
if { $n_other > 0 } {
    append auto_assignment_html_header "<td class=rowtitle>[_ intranet-translation.Other]</td\n>"
    append auto_assignment_html_body "<td>[im_task_user_select other_auto_id $project_resource_list ""]</td>\n"
}

set auto_assignment_html "
<form action=\"task-assignments\" method=POST>
[export_form_vars project_id return_url orderby]
<table>
<tr>
  <td colspan=5 class=rowtitle align=center>[_ intranet-translation.Auto_Assignment]</td>
</tr>
<tr align=center>
  $auto_assignment_html_header
</tr>
<tr>
  $auto_assignment_html_body
</tr>
<tr>
  <td align=left colspan=5>
    <input type=submit name='auto_assigment' value='[_ intranet-translation.Auto_Assign]'>
  </td>
</tr>
</table>
</form>
"

# No static tasks - no auto assignment...
if {"" == $task_html} { set auto_assignment_html "" }

# -------------------------------------------------------------------
# Mass_Assign HTML Component
# -------------------------------------------------------------------

set mass_assignment_html_body ""
set mass_assignment_html_header ""

append mass_assignment_html_header "<td class=rowtitle>[_ intranet-translation.Target_Lang]</td>\n"
if {$n_trans>0} {
    append mass_assignment_html_header "<td class=rowtitle>[_ intranet-translation.Trans]</td>\n"
}
if {$n_edit>0} {
    append mass_assignment_html_header "<td class=rowtitle>[_ intranet-translation.Edit]</td>\n"
}
if {$n_proof>0} {
    append mass_assignment_html_header "<td class=rowtitle>[_ intranet-translation.Proof]</td>\n"
}
if {$n_other>0} {
    append mass_assignment_html_header "<td class=rowtitle>[_ intranet-translation.Other]</td>\n"
}

foreach target_language_id $target_language_ids {
    append mass_assignment_html_body "<tr><td>[im_category_from_id $target_language_id]</td>\n"
    foreach type {trans edit proof other} {
        if { [set n_${type}] > 0 } {
            append mass_assignment_html_body "<td>[im_task_user_select -source_language_id $orig_source_language_id -target_language_id $target_language_id -with_no_change ${type}_mass.$target_language_id $project_resource_list "" translator]</td>\n"
        } else {
	        append mass_assignment_html_body "<input type=hidden name=${type}_mass.$target_language_id value=''>"
        }
    }
     append mass_assignment_html_body "</tr>"
} 

# Now add a line for the end date
append mass_assignment_html_body "<tr><td>[_ intranet-core.End_Date]</td>\n"
foreach type {trans edit proof other} {
	if { [set n_${type}] > 0 } {
		set end_date [lindex [lsort -unique [set ${type}_end_dates]] 0]
			
		# Use ad_form templating for consistent looks

		# if {[regexp {^(\d{4})\-(\d{2})\-(\d{2}) (\d{2}):(\d{2}):(\d{2})\+(\d{2})$} $end_date match year moy dom hod moh som tz]} { set end_date [list $year $moy $dom $hod $moh $som $tz] }
		# set element(name) ${type}_end_date
		# set element(value) $end_date
		# set element(mode) "edit"
		# append mass_assignment_html_body "<td>[template::widget::timestamp element ""]</td>"
		append mass_assignment_html_body "<td><input type=text size=25 maxlength=25 name=${type}_end_date value=\"$end_date\"></td>"	
	} else {
		append mass_assignment_html_body "<input type=hidden name=${type}_end_date value=''>"
	}
}
append mass_assignment_html_body "</tr>"

set task_type_list [array get task_types]
set mass_assignment_html "
<form action=\"task-assignments-mass\" method=POST>
[export_form_vars project_id target_language_ids return_url orderby task_type_list]
<table>
<tr>
  <td colspan=5 class=rowtitle align=center>[_ intranet-translation.Mass_Assignment]</td>
</tr>
<tr align=center>
  $mass_assignment_html_header
</tr>
  $mass_assignment_html_body
<tr>
  <td align=left colspan=5>
    <input type=submit name='mass_assigment' value='[_ intranet-translation.Auto_Assign]'>
  </td>
</tr>
</table>
</form>
"

# No static tasks - no mass assignment...
if {"" == $task_html} { set mass_assignment_html "" }

# -------------------------------------------------------------------
# Project Subnavbar
# -------------------------------------------------------------------

set bind_vars [ns_set create]
ns_set put $bind_vars project_id $project_id
set parent_menu_id [db_string parent_menu "select menu_id from im_menus where label='project'" -default 0]

set sub_navbar [im_sub_navbar \
    -components \
    -base_url "/intranet/projects/view?project_id=$project_id" \
    $parent_menu_id \
    $bind_vars "" "pagedesriptionbar" "project_trans_tasks_assignments"] 

