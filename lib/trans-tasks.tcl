# Is this a translation project?
if {![im_project_has_type $project_id "Translation Project"]} {
    return ""
}
    
set workflow_url [im_workflow_url]
set current_user_id $user_id
set admin_p [im_is_user_site_wide_or_intranet_admin $user_id]
set date_format [parameter::get_from_package_key -package_key intranet-translation -parameter "TaskListEndDateFormat" -default "YYYY-MM-DD"]
set date_format_len [string length $date_format]
set default_currency [ad_parameter -package_id [im_package_cost_id] "DefaultCurrency" "" "EUR"]

# Get the permissions for the current _project_
im_project_permissions $user_id $project_id project_view project_read project_write project_admin

# Ophelia translation Memory Integration?
# Then we need links to Opehelia instead of upload/download buttons
set ophelia_installed_p [llength [info procs im_package_ophelia_id]]

# Is the dynamic WorkFlow module installed?
set wf_installed_p [im_workflow_installed_p]
    
# Get the projects end date as a default for the tasks
set project_end_date [db_string project_end_date "select to_char(end_date, :date_format) from im_projects where project_id = :project_id" -default ""]
    
set company_view_page "/intranet/companies/view"

# Inter-Company invoicing enabled?
set interco_p [parameter::get_from_package_key -package_key "intranet-translation" -parameter "EnableInterCompanyInvoicingP" -default 0]
    
# Main project
set main_project_id [db_string main_project "select project_id from im_projects where tree_sortkey = (select tree_root_key(tree_sortkey) from im_projects where project_id = :project_id)" -default ""]
    
# -------------------- Column Selection ---------------------------------
# Define the column headers and column contents that
# we want to show:
#
set view_id [db_string get_view_id "select view_id from im_views where view_name=:view_name"]
set column_headers [list]
set column_headers_admin [list]
set column_vars [list]
set extra_selects [list]
set extra_froms [list]
set extra_wheres [list]
set view_order_by_clause ""
    
set column_sql "
select
    vc.*
from
    im_view_columns vc
where
    view_id=:view_id
    and group_id is null
order by
    sort_order"

set ctr 0
db_foreach column_list_sql $column_sql {
    set admin_html ""
    if {$admin_p} { 
        set url [export_vars -base "/intranet/admin/views/new-column" {{column_id $column_id} return_url}]
        set admin_html "<a href='$url'>[im_gif wrench ""]</a>" 
    }

    if {"" == $visible_for || [eval $visible_for]} {
        lappend column_headers "[lang::util::localize $column_name]"
        lappend column_vars "$column_render_tcl"
        lappend column_headers_admin $admin_html
        if {"" != $extra_select} { lappend extra_selects $extra_select }
        if {"" != $extra_from} { lappend extra_froms $extra_from }
        if {"" != $extra_where} { lappend extra_wheres $extra_where }
        if {"" != $order_by_clause && $order_by==$column_name} {
            set view_order_by_clause $order_by_clause
        }
    }
}   

# -------------------- Header ---------------------------------
set task_table "
    <form action=/intranet-translation/trans-tasks/task-action method=POST>
    [export_form_vars project_id return_url]
    <table border=0>
    <tr>
"

foreach col $column_headers {
    set wrench_html [lindex $column_headers_admin $ctr]
    regsub -all {"} $col {,} col
    set header ""
    set header_cmd "set header \"$col\""
    eval $header_cmd
    if { [regexp "im_gif" $col] } {
        set header_tr $header
    } else {
        set header_tr [lang::message::lookup "" intranet-translation.[lang::util::suggest_key $header] $header]
    }
    append task_table "<td class=rowtitle>$header_tr $wrench_html</td>\n"
    incr ctr
}
append task_table "\n</tr>\n"
    
        # -------------------------------------------------------------------
        # Build the assignments table
        #
        # This query extracts all tasks and all of the task assignments and
        # stores them in an two-dimensional matrix (implmented as a hash).
    
        # ToDo: Use this ass(...) field instead of the SQL for each task line
        set wf_assignments_sql "
            select distinct
                    t.task_id,
                    wfc.case_id,
                    wfc.workflow_key,
                    wft.transition_key,
                    wft.trigger_type,
                    wft.sort_order,
                    wfca.party_id
            from
                    im_trans_tasks t
                    LEFT OUTER JOIN wf_cases wfc ON (t.task_id = wfc.object_id)
                    LEFT OUTER JOIN wf_transitions wft ON (wfc.workflow_key = wft.workflow_key)
                    LEFT OUTER JOIN wf_case_assignments wfca ON (
                            wfca.case_id = wfc.case_id
                            and wfca.role_key = wft.role_key
                    )
            where
                    t.project_id = :project_id
                    and wft.trigger_type != 'automatic'
            order by
                    wfc.workflow_key,
                    wft.sort_order
        "
    
        db_foreach wf_assignment $wf_assignments_sql {
        set ass_key "$task_id $transition_key"
        set ass($ass_key) $party_id
        ns_log Debug "im_task_component: DynWF Assig: wf='$workflow_key': '$ass_key' -> '$party_id'"
        }
    
    
        # -------------------------------------------------------------------
        # Build the price/cost table
        #
        # This query extracts all "line items" of quotes and POs in the project
        # together with propoerties like source- and target_language etc.
        # Searching through this table we will be able to determine the gross
        # margin per task.
    
        # Get the list of DynField parameters of im_material that are the base
        # for looking up the price later.
        set material_dynfield_sql "
            select  *
            from    acs_attributes aa,
                    im_dynfield_widgets dw,
                    im_dynfield_attributes da
                    LEFT OUTER JOIN im_dynfield_layout dl ON (da.attribute_id = dl.attribute_id)
            where   aa.object_type = 'im_material' and
                    aa.attribute_id = da.acs_attribute_id and
                    da.widget_name = dw.widget_name and
                    coalesce(dl.page_url,'default') = 'default'
            order by dl.pos_y, lower(aa.attribute_name)
        "
        set material_dynfields [db_list material_dynfields "select attribute_name from ($material_dynfield_sql) t"]
    
        # Get all line items for all financial documents in this project.
        # We only need to consider items with material_id != NULL.
        set price_cost_sql "
        select	m.*,
            ii.invoice_id,
            ii.item_units,
            ii.price_per_unit,
            round((ii.price_per_unit * im_exchange_rate(c.effective_date::date, ii.currency, :default_currency)) :: numeric, 2) as price_per_unit,
            c.cost_type_id as invoice_type_id
        from	im_invoices i,
            im_costs c,
            im_invoice_items ii,
            im_materials m
        where	i.invoice_id = c.cost_id and
            i.invoice_id = ii.invoice_id and
            ii.item_material_id = m.material_id and
            i.invoice_id in (
                -- Get all financial documents associated with the main project or its children
                select	r.object_id_two
                from	im_projects parent,
                    im_projects child,
                    acs_rels r
                where	parent.project_id = :main_project_id and
                    child.tree_sortkey between parent.tree_sortkey and tree_right(parent.tree_sortkey) and
                    child.project_status_id not in ([im_project_status_deleted]) and
                    r.object_id_one = child.project_id
            )
        "
        set price_cost_lines [list]
        db_foreach price_cost $price_cost_sql {
        set line [list]
        lappend line invoice_id $invoice_id invoice_type_id $invoice_type_id
            lappend line item_units $item_units price_per_unit $price_per_unit
            foreach param $material_dynfields { lappend line $param [eval "set a \$${param}"] }
        lappend price_cost_lines $line
        }
    
        # -------------------- Task List SQL -----------------------------------
        #
        set bgcolor(0) " class=roweven"
        set bgcolor(1) " class=rowodd"
        set trans_project_words 0
        set trans_project_hours 0
        set ctr 0
        set task_table_rows ""
    
        # Initialize the counters for all UoMs
        db_foreach init_uom_counters "
        select category_id as uom_id 
        from im_categories 
        where category_type = 'Intranet UoM'
        " {
        set project_size_uom_counter($uom_id) 0
        }
    
        set project_where "t.project_id = :project_id"
        if {$include_subprojects_p} {
        set project_where "
            t.project_id in (
                select
                children.project_id
                from
                im_projects parent,
                im_projects children
                where
                children.project_status_id not in (
                    [im_project_status_deleted],
                    [im_project_status_canceled]
                )
                and children.tree_sortkey 
                    between parent.tree_sortkey 
                    and tree_right(parent.tree_sortkey)
                and parent.project_id = :project_id
            )
        "
        }
    
        set extra_select ""
        set extra_from ""
        set extra_where ""
    
        if {$wf_installed_p} {
        set extra_select ",
            wft.*
        "
        set extra_from "
        LEFT OUTER JOIN (
            select  wfc.object_id,
                wft.case_id,
                wft.place_key,
                wft.state,
                wft.workflow_key
            from    wf_tokens wft,
                (select *
                from    wf_cases
                where   object_id in (
                        select task_id
                        from im_trans_tasks
                        where project_id = :project_id
                    )
                ) wfc
            where   wft.case_id = wfc.case_id
                and wft.state != 'consumed'
        ) wft on (t.task_id = wft.object_id)
        "
        }
    
        set last_task_id 0
        db_foreach select_tasks "
        select 
            t.*,
            p.subject_area_id,
            p.source_language_id,
            im_category_from_id(t.tm_integration_type_id) as tm_integration_type,
            to_char(t.end_date, :date_format) as end_date_formatted,
                im_category_from_id(t.source_language_id) as source_language,
                im_category_from_id(t.target_language_id) as target_language,
                im_category_from_id(t.task_status_id) as task_status,
            im_category_from_id(t.task_uom_id) as uom_name,
            im_category_from_id(t.task_type_id) as type_name,
                im_initials_from_user_id (t.trans_id) as trans_name,
                im_initials_from_user_id (t.edit_id) as edit_name,
                im_initials_from_user_id (t.proof_id) as proof_name,
                im_initials_from_user_id (t.other_id) as other_name
            $extra_select
        from 
            im_projects p,
            im_trans_tasks t
            $extra_from
        where
            t.project_id = p.project_id and
            $project_where
            $extra_where
        order by
            t.task_name,
            t.target_language_id
        " {
    
        ns_log Debug "im_task_component: task: task_id $task_id task_uom_id $task_uom_id task_type_id $task_type_id source_language_id $source_language_id target_language_id $target_language_id subject_area_id $subject_area_id"
    
        set dynamic_task_p 0
        if {$wf_installed_p} {
            if {"" != $workflow_key} { set dynamic_task_p 1 }
        }
    
        if {$task_id == $last_task_id} {
            # Duplicated task - this is probably due to an error with
            # the dynamic workflow. "Duplicated" tasks can be created
            # (only in the SQL query) if there is more then one token
            # active for the given task. That's fine with the generic
            # WF, but not with the way how we're using it here.
            # => Issue an Error message, but continue
            ns_log Error "im_task_component: Found duplicated task=$task_id probably after task-action: skipping"
            continue
        }
        set last_task_id $task_id
    
        # Deal with incomplete task information - may occur after 
        # an error condition when uploading tasks or by an external
        # application
        if {"" == $task_units} { set task_units 0 }
    
    
        # Determine if $user_id is assigned to some phase of this task
        set user_assigned 0
        if {$trans_id == $user_id} { set user_assigned 1 }
        if {$edit_id == $user_id} { set user_assigned 1 }
        if {$proof_id == $user_id} { set user_assigned 1 }
        if {$other_id == $user_id} { set user_assigned 1 }
    
        # Freelancers shouldn't see tasks if they are not assigned to it.
        if {!$user_assigned && ![im_permission $user_id view_trans_tasks]} {
            continue
        }
    
        # Build a string with the user short names for the assignations
        set assignments ""
        if {$trans_name != ""} { append assignments "T: <A HREF=/intranet/users/view?user_id=$trans_id>$trans_name</A> " }
        if {$edit_name != ""} { append assignments "E: <A HREF=/intranet/users/view?user_id=$edit_id>$edit_name</A> " }
        if {$proof_name != ""} { append assignments "P: <A HREF=/intranet/users/view?user_id=$proof_id>$proof_name</A> " }
        if {$other_name != ""} { append assignments "<A HREF=/intranet/users/view?user_id=$other_id>$other_name</A> " }
    
        # Replace "/" characters in the Task Name (filename) by "/ ",
        # to allow the line to break more smoothely
        set task_name_list [split $task_name "/"]
        set task_name_splitted [join $task_name_list "/ "]
    
        # Add a " " at the beginning of uom_name in order to separate
        # it from the number of units:
        set uom_name " $uom_name"
    
        # Billable Items 
        set billable_items_input "<input type=text size=3 name=billable_units.$task_id value=$billable_units>"
        set billable_items_input_interco "<input type=text size=3 name=billable_units_interco.$task_id value=$billable_units_interco>"
    
            # Description
            set description_input "<textarea name=description.$task_id rows=3>$description</textarea>"
    
        # End Date Input Field
        if {"" == $end_date_formatted} { set end_date_formatted $project_end_date }
        set end_date_input "<input type=text size=$date_format_len maxlength=$date_format_len name=end_date.$task_id value=\"$end_date_formatted\">"
    
    
        # ------------------------------------------
        # Status Select Box
    
        if {!$dynamic_task_p} {
    
            # Static  WF: Show the task status directly
            set status_select [im_category_select "Intranet Translation Task Status" task_status.$task_id $task_status_id]
    
        } else {
    
            # Dynamic WF: Show the WF "Places" instead of task status
            set status_select "
            <input type=hidden name=\"task_status.$task_id\" value=\"$task_status_id\">\n"
            append status_select [im_workflow_status_select \
            -include_empty 0 \
            $workflow_key \
            task_wf_status.$task_id \
            $place_key
            ]
        }
    
        # ------------------------------------------
        # Type Select Box
        # ToDo: Introduce its own "Intranet Translation Task Type".
    
        if {!$dynamic_task_p} {
    
            # Static WF: Show drop-down to change the type
            set type_select [im_trans_task_type_select task_type.$task_id $task_type_id]
        } else {
    
            # Dynamic WF: We can't change the type for the WF while
            # executing the task. The user needs to delete and recreate
            # the task.
            set wf_pretty_name [im_workflow_pretty_name $workflow_key]
            set workflow_view_url "/$workflow_url/case?case_id=$case_id"
            set type_select "
            <input type=hidden name=\"task_type.$task_id\" value=\"$task_type_id\">
            <a href=\"$workflow_view_url\">$wf_pretty_name</a>
            "
        }
    
        # Delete Checkbox
        set bulk_checkbox "<input type=checkbox name=bulk_task_id value=$task_id id=\"bulk_task_id,$task_id\">"
    
        # ------------------------------------------
        # price and cost
        # Check if we find suitable entries for the material's parameters in the quote/PO lines
        # of the project.
    
        set quoted_price_min ""
        set quoted_price_max ""
        set po_cost_min ""
        set po_cost_max ""
    
        set invoice_type_id ""
            set po_cost ""
        set quoted_price ""
        set gross_margin ""
    
        # set price_cost_lines [lrange $price_cost_lines 0 end-1]
        # ad_return_complaint 1 "<pre>[join $price_cost_lines "\n"]</pre>"
        foreach line_list $price_cost_lines {
    
            # Load the list into a hash
            array unset line_hash
            array set line_hash $line_list
            ns_log Debug "im_task_component: line: $line_list"
    
            # Check if the lines has the same parameters as the current task	    
            set found_p 1
            foreach dynfield $material_dynfields {
            set task_value [eval "set a \$$dynfield"]
            ns_log Debug "im_task_component: $dynfield=$task_value"
            set line_value $line_hash($dynfield)
            if {$task_value != $line_value} { 
                set found_p 0 
                ns_log Debug "im_task_component: found_p=$found_p because of $dynfield"
            }
            }
            ns_log Debug "im_task_component: found_p=$found_p"
            if {!$found_p} { continue }
    
            # We have found a perfectly matching price/cost line for this task.
            # Let's check that it's a Quote or PO and assign the price to the right
            # field
            set invoice_type_id $line_hash(invoice_type_id)
            set amount $line_hash(price_per_unit)
            ns_log Debug "im_task_component: invoice_id=$invoice_id, type_id=$invoice_type_id, amount=$amount"
            switch $invoice_type_id {
            3702 {
                # Quote
                if {"" == $quoted_price_min} { set quoted_price_min $amount }
                if {"" == $quoted_price_max} { set quoted_price_max $amount }
                if {$amount < $quoted_price_min} { set quoted_price_min $amount }
                if {$amount > $quoted_price_max} { set quoted_price_max $amount }
            }
            3706 {
                # Purchase Order
                if {"" == $po_cost_min} { set po_cost_min $amount }
                if {"" == $po_cost_max} { set po_cost_max $amount }
                if {$amount < $po_cost_min} { set po_cost_min $amount }
                if {$amount > $po_cost_max} { set po_cost_max $amount }
            }
            default {
                # Ignore any other type.
            }
            }
        }
    
            ns_log Debug "im_task_component: invoice_id=$invoice_id, type_id=$invoice_type_id, qmin=$quoted_price_min, qmax=$quoted_price_max"
            ns_log Debug "im_task_component: invoice_id=$invoice_id, type_id=$invoice_type_id, pmin=$po_cost_min, pmax=$po_cost_max"
    
        set gross_margin_valid_p 1
        if {$quoted_price_min == $quoted_price_max} {
            set quoted_price $quoted_price_min
            if {"" == $quoted_price} { set gross_margin_valid_p 0 }
        } else {
            set quoted_price "$quoted_price_min - $quoted_price_max"
            set gross_margin_valid_p 0
        }
    
        if {$po_cost_min == $po_cost_max} {
            set po_cost $po_cost_min
            if {"" == $po_cost} { set gross_margin_valid_p 0 }
        } else {
            set po_cost "$po_cost_min - $po_cost_max"
            set gross_margin_valid_p 0
        }
    
        if {$gross_margin_valid_p} { set gross_margin "[expr round(10.0 * 100.0 * ($quoted_price - $po_cost) / $quoted_price) / 10.0]%" }
    
    #        if {"" != $quoted_price} { set quoted_price "$quoted_price $default_currency" }
    #        if {"" != $po_cost} { set po_cost "$po_cost $default_currency" }
    
        # ------------------------------------------
        # The Static Workflow -
        # Call im_task_component_upload to determine workflow status and message
        #
        if {!$dynamic_task_p} {
    
            # Nothing specified at the task level how to handle the task.
            # => Asume "External" (File System) integration, just the static old solution...
            if {"" == $tm_integration_type} { set tm_integration_type "External" }
    
            ns_log Debug "im_task_component: Static WF"
            # Message - Tell the freelancer what to do...
            # Check if the user is a freelance who is allowed to
            # upload a file for this task, depending on the task
            # status (engine) and the assignment to a specific phase.
            set upload_list [im_task_component_upload $user_id $project_admin $task_status_id $task_type_id $source_language $target_language $trans_id $edit_id $proof_id $other_id]
    
            set download_folder [lindex $upload_list 0]
            set upload_folder [lindex $upload_list 1]
            set message [lindex $upload_list 2]
            ns_log Debug "im_task_component: download_folder=$download_folder, upload_folder=$upload_folder"
    
            # Download Link - where to get the task file
            set download_link ""
            if {$download_folder != ""} {
    
            switch $tm_integration_type {
                External {
                # Standard - Download to start editing
                set download_url "/intranet-translation/download-task/$task_id/$download_folder/$task_name"
                set download_gif [im_gif -translate_p 1 save "Click right and choose \"Save target as\" to download the file"]
                }
                Ophelia {
    
                # Ophelia - Redirect to Ophelia page
                set download_url [export_vars -base "/intranet-ophelia/task-start" {task_id project_id return_url}]
                set download_help [lang::message::lookup "" intranet-translation.Start_task "Start the task"]
                set download_gif [im_gif -translate_p 0 control_play_blue $download_help]
                }
                default {
    
                set download_url ""
                set download_gif ""
                set message "Bad TM Integration Type: '$tm_integration_type'"
    
                }
            }
    
            set download_link "<A HREF='$download_url'>$download_gif</A>\n"
            }
    
            # Upload Link
            set upload_link ""
            if {$upload_folder != ""} {
    
            switch $tm_integration_type {
                External {
                # Standard - Upload to stop editing
                set upload_url "/intranet-translation/trans-tasks/upload-task?"
                append upload_url [export_url_vars project_id task_id case_id transition_key return_url]
                set upload_gif [im_gif -translate_p 1 open "Upload File"]
                }
                Ophelia {
                # Ophelia - Redirect to Ophelia page
                set upload_url [export_vars -base "/intranet-ophelia/task-end" {task_id project_id case_id transition_key return_url}]
                set upload_help [lang::message::lookup "" intranet-translation.Mark_task_as_finished "Mark the task as finished"]
                set upload_gif [im_gif -translate_p 0 control_stop_blue $upload_help]
                }
                default {
                set upload_url ""
                set upload_gif ""
    
                }
            }
            set upload_link "<A HREF='$upload_url'>$upload_gif</A>\n"
            }
        }
    
    
        # ------------------------------------------
        # The Dynamic Workflow -
        # - Check if the current user is assigned to the task
        # - Display a Start or End button, depending on the status
        # - Show a message with the task
        if {$dynamic_task_p} {
    
            ns_log Debug "im_task_component: Dynamic WF"
            # Check for the currently enabled Tasks
            # This should be only one task at a time in a simplified
            # PetriNet without parallelism
            #
            set transitions [db_list_of_lists enabled_tasks "
            select distinct
                t.task_id,
                t.state as task_state,
                t.transition_name,
                t.transition_key
            from
                wf_cases c,
                wf_user_tasks t
            where
                c.case_id = :case_id
                and t.user_id = :current_user_id
                and c.case_id = t.case_id
                and t.state in ('enabled', 'started')
            "]
    
    
            if {[llength $transitions] > 1} {
            ad_return_complaint 1 "More then one task 'enabled' or 'started':<br>
            There is currently more then one task active in case# $case_id.
            This should not occure in normal operations. Please check why there
            is more then one task active at the same time and notify your
            system administrator."
            return
            }
    
            # Get the first task only
            set transition [lindex $transitions 0]
    
            # Retreive the variables
            set transition_task_id [lindex $transition 0]
            set transition_state [lindex $transition 1]
            set transition_name [lindex $transition 2]
            set transition_key [lindex $transition 3]
    
            switch $transition_state {
            "enabled" {
                set message "Press 'Start' to start '$transition_name'"
                set download_help $message
                set download_gif [im_gif -translate_p 0 control_play_blue $download_help]
                set download_url [export_vars -base "/$workflow_url/task" {{task_id $transition_task_id} return_url}]
                set download_link "<A HREF='$download_url'>$download_gif</A>\n"
                set upload_link ""
            }
            "started" {
                set message "Press 'Stop' to finish '$transition_name'"
                set upload_help $message
                set upload_gif [im_gif -translate_p 0 control_stop_blue $upload_help]
                set upload_url [export_vars -base "/$workflow_url/task" {{task_id $transition_task_id} return_url}]
                set upload_link "<A HREF='$upload_url'>$upload_gif</A>\n"
                set download_link ""
            }
            "" {
                # No activity 
                set message ""
                set upload_help $message
                set upload_link ""
                set download_link ""
            }
            default {
                set message "Error with task in state '$transition_state'"
                set upload_help $message
                set upload_link ""
                set download_link ""
            }
            }
        }
    
        # Render the line using the dynamic columns from the database im_views
        append table_body_html "<tr$bgcolor([expr $ctr % 2])>\n"
        set col_ctr 0
        foreach column_var $column_vars {
            append task_table "\t<td$bgcolor([expr $ctr % 2]) valign=top>"
            set cmd "append task_table $column_var"
            eval $cmd
            append task_table "</td>\n"
            incr col_ctr
        }
        append task_table "</tr>\n"
    
        incr ctr
        set uom_size $project_size_uom_counter($task_uom_id)
        set project_size_uom_counter($task_uom_id) [expr $uom_size + $task_units]
    
        if {$task_uom_id == [im_uom_s_word]} { set trans_project_words [expr $trans_project_words + $task_units] }
        if {$task_uom_id == [im_uom_hour]} { set trans_project_hours [expr $trans_project_hours + $task_units] }
        }
    
        if {$ctr > 0} {
         append task_table $task_table_rows
        } else {
         append task_table "<tr><td colspan=7 align=center>[_ intranet-translation.No_tasks_found]</td></tr>"
        }
    
        # -------------------- Calculate the project size -------------------------------
    
        set project_size ""
        db_foreach project_size "select category_id as uom_id, category as uom_unit from im_categories where category_type = 'Intranet UoM'" {
        set uom_size [expr round($project_size_uom_counter($uom_id))]
        if {0 != $uom_size} {
            set comma ""
            if {"" != $project_size} { set comma ", " }
            append project_size "$comma$uom_size $uom_unit"
        }
        }
    
        db_dml update_project_size "
        update im_projects set 
            trans_project_words = :trans_project_words,
            trans_project_hours = :trans_project_hours,
            trans_size = :project_size
        where project_id = :project_id
        "
    
        # -------------------- Action Row -------------------------------
        # End of the task-list loop.
        # Start formatting the the adding new tasks line etc.
    
        # Show "Save, Del, Assign" buttons only for admins and 
        # only if there is atleast one row to act upon.
        if {$project_admin && $ctr > 0} {
        append task_table "
    <tr align=right> 
      <td colspan=15 align=left>
        <select name=action>
        <option value='save' selected>[lang::message::lookup "" intranet-translation.Save_Changes "Save Changes"]</option>
        <option value='batch'>[lang::message::lookup "" intranet-translation.Create_Batch "Create Batch"]</option>
        <option value='delete'>[lang::message::lookup "" intranet-translation.Delete "Delete"]</option>
        </select>
        <input type=submit name=submit_submit value=\"[lang::message::lookup "" intranet-translation.Submit "Submit"]\">
      </td>
    </tr>"
        }
    
        append task_table "
    </table>
    </form>\n"