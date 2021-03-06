# /packages/intranet-translation/tcl/intranet-trans-procs.tcl
#
# Copyright (C) 2004 - 2009 ]project-open[
#
# All rights reserved (this is not GPLed software!).
# Please check http://www.project-open.com/ for licensing
# details.

ad_library {
    Bring together all "components" (=HTML + SQL code)
    related to the Translation sector

    @author frank.bergmann@project-open.com
    @author juanjoruizx@yahoo.es
}

# -------------------------------------------------------------------
# Additional constant functions
# -------------------------------------------------------------------

ad_proc -public im_project_type_trans_edit {} { return 87 }
ad_proc -public im_project_type_edit {} { return 88 }
ad_proc -public im_project_type_trans_edit_proof {} { return 89 }
ad_proc -public im_project_type_ling_validation {} { return 90 }
ad_proc -public im_project_type_localization {} { return 91 }
ad_proc -public im_project_type_technology {} { return 92 }
ad_proc -public im_project_type_trans {} { return 93 }
ad_proc -public im_project_type_trans_spot {} { return 94 }
ad_proc -public im_project_type_proof {} { return 95 }
ad_proc -public im_project_type_glossary_comp {} { return 96 }
ad_proc -public im_project_type_translation {} { return 2500 }

ad_proc -public im_trans_tm_integration_type_external {} { return 4200 }
ad_proc -public im_trans_tm_integration_type_ophelia {} { return 4202 }
ad_proc -public im_trans_tm_integration_type_none {} { return 4204 }


# 60000-60999  Translation Task Type CSV Importer (1000)


# -------------------------------------------------------------------
#
# -------------------------------------------------------------------


ad_proc -public im_package_translation_id { } {
} {
    return [util_memoize im_package_translation_id_helper]
}

ad_proc -private im_package_translation_id_helper {} {
    return [db_string im_package_core_id {
        select package_id from apm_packages
        where package_key = 'intranet-translation'
    } -default 0]
}


ad_proc -public im_workflow_installed_p { } {
    Is the dynamic WorkFlow module installed?
} {
    set wf_installed_p [llength [info proc im_package_workflow_id]]
}



# -------------------------------------------------------------------
# Drop-Down "Selects"
# -------------------------------------------------------------------

ad_proc -public im_trans_task_type_select { 
    {-translate_p 0}
    {-package_key "intranet-core" }
    {-locale ""}
    {-include_empty_p 0}
    {-include_empty_name "All"}
    select_name 
    { default "" } 
} {
    Returns an html select box named $select_name and defaulted to 
    $default with a list of translation task types.
    This procedure checks the case that there is no "Intranet Trans
    Task Type" category entries and the reverts to "Intranet Project
    Type".
} {
    set trans_type_exists_p [util_memoize [list db_string ttypee "select count(*) from im_categories where category_type = 'Intranet Translation Task Type'"]]
    if {$trans_type_exists_p} {
		return [im_category_select -translate_p $translate_p -package_key $package_key -locale $locale -include_empty_p $include_empty_p -include_empty_name $include_empty_name "Intranet Translation Task Type" $select_name $default]
    } else {
		return [im_category_select -translate_p $translate_p -package_key $package_key -locale $locale -include_empty_p $include_empty_p -include_empty_name $include_empty_name "Intranet Project Type" $select_name $default]
    }
}


ad_proc -public im_trans_task_type_options { 
    {-translate_p 0}
    {-package_key "intranet-core" }
} {
    Return a list of options for translation task type.
} {
    set trans_type_exists_p [util_memoize [list db_string ttypee "select count(*) from im_categories where category_type = 'Intranet Translation Task Type'"]]
    if {$trans_type_exists_p} {
		return [db_list_of_lists type "select category, category_id from im_categories where category_type = 'Intranet Trans Task Type'"]
    } else {
		return [db_list_of_lists type "select category, category_id from im_categories where category_type = 'Intranet Project Type'"]
    }
}


# -------------------------------------------------------------------
# Serve the abstract URLs to download im_trans_tasks files and
# to advance the task status.
# -------------------------------------------------------------------

# Register the download procedure for a URL of type:
# /intranet-translation/download-task/<task_id>/<path for the browser but ignored here>
#
ad_register_proc GET /intranet-translation/download-task/* intranet_task_download

proc intranet_task_download {} {
    set user_id [ad_maybe_redirect_for_registration]

    set url "[ns_conn url]"
    ns_log Debug "intranet_task_download: url=$url"

    # Using the task_id as only reasonable identifier
    set path_list [split $url {/}]
    set len [expr [llength $path_list] - 1]

    # +0:/ +1:intranet-translation, +2:download-task, +3:<task_id>, +4:...
    set task_id [lindex $path_list 3]
    set task_path [lindex $path_list 4]
    set task_file_body [lindex $path_list 5]
    ns_log Debug "intranet_task_download: task_id=$task_id, task_path=$task_path, task_body=$task_file_body"

    # Make sure $task_id is a number and emit an error otherwise!

    # get everything about the specified task
    set task_sql "
select
	t.*,
	p.project_nr,
	p.project_type_id,
	im_name_from_user_id(p.project_lead_id) as project_lead_name,
	im_email_from_user_id(p.project_lead_id) as project_lead_email,
	im_category_from_id(t.source_language_id) as source_language,
	im_category_from_id(t.target_language_id) as target_language
from
	im_trans_tasks t,
	im_projects p
where
	t.task_id = :task_id
	and t.project_id = p.project_id"

    if {![db_0or1row task_info_query $task_sql] } {
	doc_return 403 text/html "[_ intranet-translation.lt_Task_task_id_doesnt_e]"
	return
    }

    # Now we can check if the user permissions on the project:
    #
    set user_is_admin_p [im_is_user_site_wide_or_intranet_admin $user_id]
    set user_is_group_admin_p [im_biz_object_admin_p $user_id $project_id]
    set user_is_employee_p [im_user_is_employee_p $user_id]
    set user_admin_p [expr $user_is_admin_p || $user_is_group_admin_p]

    # Dependency with Filestorage module:
    # We need to know where the task-files are stored in the filesystem
    set project_path [im_filestorage_project_path $project_id]

    # Get the download/upload permission for this task:
    # #1: Download folder or "" if not allowed to download
    # #2: Upload folder or "" if not allowed to upload
    # #3: A message for the user (ignored here)
    set upload_list [im_task_component_upload $user_id $user_admin_p $task_status_id $task_type_id $source_language $target_language $trans_id $edit_id $proof_id $other_id]
    set download_folder [lindex $upload_list 0]
    set upload_folder [lindex $upload_list 1]
    ns_log Debug "intranet_task_download: download_folder=$download_folder, upload_folder=$upload_folder"

    # Allow to download the file if the user is an admin, a project admin
    # or an employee of the company. Or if the task is assigned to the user.
    #
    set allow 0
    if {$user_admin_p} { set allow 1}
    if {$user_is_employee_p} { set allow 1}
    if {$download_folder != ""} {set allow 1}
    if {!$allow} {
		doc_return 403 text/html "[_ intranet-translation.lt_You_are_not_allowed_t_1]"
    }

    set alternative_files [list]
    # Check for the files uploaded by the translator previously.
    catch {
        set alternative_files [db_list alt_files "
                        select distinct
                                upload_file
                        from    im_task_actions
                        where   task_id = :task_id
                                and upload_file is not NULL
        "]
    }
    set allowed_files $alternative_files
    lappend allowed_files $task_name

    # Default: Take the filename from the URL.
    set file_name $task_file_body
    set file "$project_path/$download_folder/$file_name"

    if {![file readable $file]} {
        # Check the alternative files if one exists
        foreach alt_file_body $alternative_files {
            set alt_file "$project_path/$download_folder/$alt_file_body"
            if {[file readable $alt_file]} {
                set file_name $alt_file_body
                set file "$project_path/$download_folder/$file_name"
            }
        }
    }

    if {$task_file_body != $file_name} {
        # Alternative file: We have to redirect to the new URL
        # +0:/ +1:intranet-translation, +2:download-task, +3:<task_id>, +4:<folder>, +5:<file>
        set folder [lindex $path_list 4]
        ad_returnredirect "/intranet-translation/download-task/$task_id/$folder/$alt_file_body"
        ad_script_abort
    }

    set guessed_file_type [ns_guesstype $file]

    ns_log notice "intranet_task_download: file_name=$file_name"
    ns_log notice "intranet_task_download: file=$file"
    ns_log notice "intranet_task_download: file_type=$guessed_file_type"

    if [file readable $file] {

	# Check if inside allowed files
        if {[lsearch $allowed_files $file_name] == -1} {
            # Attempted tampering with filename?
            ad_return_complaint 1 "Bad filename"
        }

	# Update the task to advance to the next status
	im_trans_download_action $task_id $task_status_id $task_type_id $user_id

	ns_log Debug "intranet_task_download: rp_serve_concrete_file $file"
        rp_serve_concrete_file $file

    } else {
	ns_log notice "intranet_task_download: file '$file' not readable"

	set subject "[_ intranet-translation.lt_File_is_missing_in_pr]"
	set subject [ad_urlencode $subject]

	ad_return_complaint 1 "<li>[_ intranet-translation.lt_The_specified_file_do]<br>
        [_ intranet-translation.lt_Your_are_trying_to_do]<p>
        [_ intranet-translation.lt_The_most_probable_cau] 
	<A href=\"mailto:$project_lead_email?subject=$subject\">
	  $project_lead_name
	</a>."
	return
    }
}


ad_proc im_task_insert {
    project_id
    task_name
    task_filename
    task_units
    task_uom
    task_type
    target_language_ids
} {
    Add a new task into the DB
} {
    # Check for accents and other non-ascii characters
    set filename $task_filename
    set charset [ad_parameter -package_id [im_package_filestorage_id] FilenameCharactersSupported "" "alphanum"]
    if {![im_filestorage_check_filename $charset $filename]} {
	ad_return_complaint 1 [lang::message::lookup "" intranet-filestorage.Invalid_Character_Set "
                <b>Invalid Character(s) found</b>:<br>
                Your filename '%filename%' contains atleast one character that is not allowed
                in your character set '%charset%'."]
    }

    set user_id [ad_get_user_id]
    set ip_address [ad_conn peeraddr]

    # Is the dynamic WorkFlow module installed?
    set wf_installed_p [im_workflow_installed_p]

    # Get some variable of the project:
    set query "
	select
		p.source_language_id,
		p.end_date as project_end_date,
		p.project_type_id
	from
		im_projects p
	where
		p.project_id = :project_id
    "
    if { ![db_0or1row projects_info_query $query] } {
	append page_body "Can't find the project $project_id"
	doc_return  200 text/html [im_return_template]
	return
    }
    
    if {"" == $source_language_id} {
	ad_return_complaint 1 "<li>[_ intranet-translation.lt_You_havent_defined_th]<br>
	[_ intranet-translation.lt_Please_edit_your_proj]"
	return
    }

    # Task just _created_
    set task_status_id 340
    set task_description ""
    set invoice_id ""
    set match100 ""
    set match95 ""
    set match85 ""
    set match0 ""

    # Add a new task for every project target language
    foreach target_language_id $target_language_ids {

	# Check for duplicated task names
	set task_name_count [db_string task_name_count "
		select count(*) 
		from im_trans_tasks 
		where 
			lower(task_name) = lower(:task_name)
			and project_id = :project_id
			and target_language_id = :target_language_id
	"]
	if {$task_name_count > 0} {
	    ad_return_complaint "[_ intranet-translation.Database_Error]" "[_ intranet-translation.lt_Did_you_enter_the_sam]"
	    return
	}

	if { [catch {
	    set new_task_id [im_exec_dml new_task "im_trans_task__new (
		null,			-- task_id
		'im_trans_task',	-- object_type
		now(),			-- creation_date
		:user_id,		-- creation_user
		:ip_address,		-- creation_ip	
		null,			-- context_id	

		:project_id,		-- project_id	
		:task_type,		-- task_type_id	
		:task_status_id,	-- task_status_id
		:source_language_id,	-- source_language_id
		:target_language_id,	-- target_language_id
		:task_uom		-- task_uom_id
		
	    )"]

	    db_dml update_task "
		UPDATE im_trans_tasks SET
			task_name = :task_name,
			task_filename = :task_filename,
			description = :task_description,
			task_units = :task_units,
			billable_units = :task_units,
			billable_units_interco = :task_units,
			match100 = :match100,
			match95 = :match95,
			match85 = :match85,
			match0 = :match0,
			end_date = :project_end_date
		WHERE 
			task_id = :new_task_id
	    "

	    if {$wf_installed_p} {
		# Check if there is a valid workflow_key for the
		# given task type and start the corresponding WF

		set workflow_key [db_string wf_key "
			select aux_string1
			from im_categories
			where category_id = :task_type
		" -default ""]

		ns_log Debug "im_task_insert: workflow_key=$workflow_key for task_type=$task_type"
		# Check that the workflow_key is available
		set wf_valid_p [db_string wf_valid_check "
			select count(*)
			from acs_object_types
			where object_type = :workflow_key
		"]
		
		if { "proof" == $workflow_key } {
			set task_status_id 352
			db_dml update_task "
                		UPDATE im_trans_tasks SET
                        		task_status_id = :task_status_id
        	        	WHERE	
                	        	task_id = :new_task_id
            		"
		}

		if {$wf_valid_p} {
		    # Context_key not used aparently...
		    set context_key ""
		    set case_id [wf_case_new \
			$workflow_key \
			$context_key \
			$new_task_id
		    ]
		}

	    }


	} err_msg] } {

	    ad_return_complaint "[_ intranet-translation.Database_Error]" "[_ intranet-translation.lt_Did_you_enter_the_sam]<BR>
	    Here is the error:<BR> <pre>$err_msg</pre>"

	} else {

	    # Successfully created translation task
	    # Call user_exit to let TM know about the event
	    im_user_exit_call trans_task_create $new_task_id
	    im_audit -object_type "im_trans_task" -action after_create -object_id $new_task_id -status_id $task_status_id -type_id $task_type
	}
    }
}




# -------------------------------------------------------------------
# Trados Matrix
# -------------------------------------------------------------------


ad_proc -public im_trans_trados_matrix_component { 
    user_id 
    object_id 
    return_url 
} {
    Return a formatted HTML table showing the trados matrix
    related to the current object
} {

    if {![im_permission $user_id view_costs]} { return "" }

    set header_html "
<td class=rowtitle align=center></td>
<td class=rowtitle align=center>[_ intranet-translation.XTr]</td>
<td class=rowtitle align=center>[_ intranet-translation.Rep]</td>

<td class=rowtitle align=center>[lang::message::lookup "" intranet-translation.Perfect "Perf"]</td>
<td class=rowtitle align=center>[lang::message::lookup "" intranet-translation.Cfr "Cfr"]</td>

<td class=rowtitle align=center>100%</td>
<td class=rowtitle align=center>95%</td>
<td class=rowtitle align=center>85%</td>
<td class=rowtitle align=center>75%</td>
<td class=rowtitle align=center>50%</td>
<td class=rowtitle align=center>0%</td>

<td class=rowtitle align=center>f95%</td>
<td class=rowtitle align=center>f85%</td>
<td class=rowtitle align=center>f75%</td>
<td class=rowtitle align=center>f50%</td>

<td class=rowtitle align=center>[lang::message::lookup "" intranet-translation.Locked "Locked"]</td>

"


    set value_html ""
    foreach trans_task_type {Trans Edit Proof} {
        
        array set matrix [im_trans_trados_matrix -task_type [string tolower $trans_task_type] $object_id]
        
        append value_html "
            <tr class=roweven>
                <td align=right class=rowtitle>[_ intranet-translation.${trans_task_type}]</td>

                <td align=right>[expr round(1000.0 * $matrix(x)) / 10.0]%</td>
                <td align=right>[expr round(1000.0 * $matrix(rep)) / 10.0]%</td>
                
                <td align=right>[expr round(1000.0 * $matrix(perf)) / 10.0]%</td>
                <td align=right>[expr round(1000.0 * $matrix(cfr)) / 10.0]%</td>
                
                <td align=right>[expr round(1000.0 * $matrix(100)) / 10.0]%</td>
                <td align=right>[expr round(1000.0 * $matrix(95)) / 10.0]%</td>
                <td align=right>[expr round(1000.0 * $matrix(85)) / 10.0]%</td>
                <td align=right>[expr round(1000.0 * $matrix(75)) / 10.0]%</td>
                <td align=right>[expr round(1000.0 * $matrix(50)) / 10.0]%</td>
                <td align=right>[expr round(1000.0 * $matrix(0)) / 10.0]%</td>
                
                <td align=right>[expr round(1000.0 * $matrix(f95)) / 10.0]%</td>
                <td align=right>[expr round(1000.0 * $matrix(f85)) / 10.0]%</td>
                <td align=right>[expr round(1000.0 * $matrix(f75)) / 10.0]%</td>
                <td align=right>[expr round(1000.0 * $matrix(f50)) / 10.0]%</td>
                
                <td align=right>[expr round(1000.0 * $matrix(locked)) / 10.0]%</td>
            </tr>
        "
    }

    set html "
        <form action=\"/intranet-translation/matrix/new\" method=POST>
        [export_form_vars object_id return_url]
        <table border=0>
        <tr class=rowtitle><td class=rowtitle colspan=16 align=center>[_ intranet-translation.Trados_Matrix] ($matrix(type))</td></tr>
        <tr class=rowtitle>$header_html</tr>
        $value_html
    "
    if {[im_permission $user_id add_costs]} {

	append html "
<tr class=rowplain>
  <td colspan=9 align=right>
    <input type=submit value=\"Edit\">
<!--  <A href=/intranet-translation/matrix/new?[export_url_vars object_id return_url]>edit</a> -->
  </td>
</tr>
"
    }

    append html "\n</table>\n</form>\n"
    return $html
}



ad_proc -public im_trans_trados_matrix_calculate { 
    object_id 
    px_words 
    prep_words 
    p100_words 
    p95_words 
    p85_words 
    p75_words 
    p50_words 
    p0_words 
    { pperfect_words 0}
    { pcfr_words 0 }
    { f95_words 0 }
    { f85_words 0 }
    { f75_words 0 }
    { f50_words 0 }
    { locked_words 0 }
    { task_type "trans"}
} {
    Calculate the number of "effective" words based on
    a valuation of repetitions from the associated tradox
    matrix.<br>
    If object_id is an "im_project", first check if the project
    has a matrix associated and then fallback to the companies
    matrix.<br>
    If the company doesn't have a matrix, fall back to the 
    "Internal" company<br>
    If the "Internal" company doesn't have a matrix fall
    back to some default values.
} {
    ns_log NOTICE "intranet-trans-procs::im_trans_trados_matrix_calculate: -------- object_id: $object_id"
    return [im_trans_trados_matrix_calculate_helper $object_id $px_words $prep_words $p100_words $p95_words $p85_words $p75_words $p50_words $p0_words \
		$pperfect_words $pcfr_words $f95_words $f85_words $f75_words $f50_words $locked_words $task_type]
}


ad_proc -public im_trans_trados_matrix_calculate_helper {
    object_id
    px_words
    prep_words
    p100_words
    p95_words
    p85_words
    p75_words
    p50_words
    p0_words 
    { pperfect_words 0}
    { pcfr_words 0 }
    { f95_words 0 }
    { f85_words 0 }
    { f75_words 0 }
    { f50_words 0 }
    { locked_words 0 }
    { task_type "trans" }
} {
    See im_trans_trados_matrix_calculate for comments...
} {
    ns_log DEBUG "intranet-trans-procs::im_trans_trados_matrix_calculate_helper: object_id: $object_id"
    ns_log DEBUG "intranet-trans-procs::im_trans_trados_matrix_calculate_helper: px_words: $px_words"
    ns_log DEBUG "intranet-trans-procs::im_trans_trados_matrix_calculate_helper: prep_words $prep_words"
    ns_log DEBUG "intranet-trans-procs::im_trans_trados_matrix_calculate_helper: p100_words $p100_words"
    ns_log DEBUG "intranet-trans-procs::im_trans_trados_matrix_calculate_helper: p95_words $p95_words"
    ns_log DEBUG "intranet-trans-procs::im_trans_trados_matrix_calculate_helper: p85_words $p85_words"
    ns_log DEBUG "intranet-trans-procs::im_trans_trados_matrix_calculate_helper: p75_words $p75_words"
    ns_log DEBUG "intranet-trans-procs::im_trans_trados_matrix_calculate_helper: p50_words $p50_words"
    ns_log DEBUG "intranet-trans-procs::im_trans_trados_matrix_calculate_helper: p0_words $p0_words"
    ns_log DEBUG "intranet-trans-procs::im_trans_trados_matrix_calculate_helper: pperfect_words $pperfect_words"
    ns_log DEBUG "intranet-trans-procs::im_trans_trados_matrix_calculate_helper: pcfr_words $pcfr_words"
    ns_log DEBUG "intranet-trans-procs::im_trans_trados_matrix_calculate_helper: f95_words $f95_words"
    ns_log DEBUG "intranet-trans-procs::im_trans_trados_matrix_calculate_helper: f85_words $f85_words"
    ns_log DEBUG "intranet-trans-procs::im_trans_trados_matrix_calculate_helper: f75_words $f75_words"
    ns_log DEBUG "intranet-trans-procs::im_trans_trados_matrix_calculate_helper: f50_words $f50_words"
    ns_log DEBUG "intranet-trans-procs::im_trans_trados_matrix_calculate_helper: locked_words $locked_words"

    if {"" == $px_words} { set px_words 0 }
    if {"" == $prep_words} { set prep_words 0 }
    if {"" == $pcfr_words} { set pcfr_words 0 }
    if {"" == $p100_words} { set p100_words 0 }
    if {"" == $p95_words} { set p95_words 0 }
    if {"" == $p85_words} { set p85_words 0 }
    if {"" == $p75_words} { set p75_words 0 }
    if {"" == $p50_words} { set p50_words 0 }
    if {"" == $p0_words} { set p0_words 0 }
    if {"" == $f95_words} { set f95_words 0 }
    if {"" == $f85_words} { set f85_words 0 }
    if {"" == $f75_words} { set f75_words 0 }
    if {"" == $f50_words} { set f50_words 0 }
    if {"" == $locked_words} { set locked_words 0 }
    if {"" == $pperfect_words} { set pperfect_words 0 }

    ns_log NOTICE "intranet-trans-procs::im_trans_trados_matrix_calculate_helper: Getting matrix for object_id: $object_id"
    array set matrix [im_trans_trados_matrix -task_type $task_type $object_id]

    ns_log NOTICE "intranet-trans-procs::im_trans_trados_matrix_calculate_helper: Array found: [array get matrix]"
    
    # ad_return_complaint xx "pperfect_words: $pperfect_words, matrix(perf):  $matrix(perf)"

    set task_units [format "%.0f" [expr \
                    ($px_words * $matrix(x)) + \
                    ($prep_words * $matrix(rep)) + \
                    ($pcfr_words * $matrix(cfr)) + \
                    ($p100_words * $matrix(100)) + \
                    ($p95_words * $matrix(95)) + \
                    ($p85_words * $matrix(85)) + \
                    ($p75_words * $matrix(75)) + \
                    ($p50_words * $matrix(50)) + \
                    ($p0_words * $matrix(0)) + \
                    ($f95_words * $matrix(f95)) + \
                    ($f85_words * $matrix(f85)) + \
                    ($f75_words * $matrix(f75)) + \
                    ($f50_words * $matrix(f50)) + \
                    ($locked_words * $matrix(locked)) + \
                    ($pperfect_words * $matrix(perf))		       
    ]]

    ns_log NOTICE "intranet-trans-procs::im_trans_trados_matrix_calculate_helper: Found task_units: $task_units" 
    return $task_units
}


ad_proc -public im_trans_trados_matrix { 
    {-task_type "trans"}
    object_id 
} {
    Returns an array with the trados matrix values for an object.
} {
    set object_type [db_string get_object_type "select object_type from acs_objects where object_id=:object_id" -default none]
    ns_log NOTICE "intranet-trans-procs::im_trans_trados_matrix: Object_id: $object_id -> object_type: $object_type"

    switch $object_type {
        	im_project {
        	    array set matrix [im_trans_trados_matrix_project -task_type $task_type $object_id]
        	}
        	im_company {
        	    array set matrix [im_trans_trados_matrix_company -task_type $task_type $object_id]
        	}
        	default {
        	    array set matrix [im_trans_trados_matrix_default]
        	}
    }

    # Make sure there are no empty values that might give errors when multplying
    foreach key [array names matrix] {
        set val $matrix($key)
        if {"" == $val} { set matrix($key) 0 }

    }

    return [array get matrix]

}


ad_proc -public im_trans_trados_matrix_project { 
    {-task_type "trans"}
    project_id 
} {
    Returns an array with the trados matrix values for a project.
} {
    ns_log NOTICE "intranet-trans-procs::im_trans_trados_matrix_project: Entering ..."    
    set count [db_string matrix_count "select count(*) from im_trans_trados_matrix where object_id=:project_id and task_type = :task_type"]
    if {!$count} { 
        	set company_id [db_string project_company "select company_id from im_projects project_id=:project_id"]
        	ns_log NOTICE "intranet-trans-procs::im_trans_trados_matrix_project: Found company_id $company_id, calling: im_trans_trados_matrix_company" 
        	return [im_trans_trados_matrix_company -task_type $task_type $company_id] 
    }

    # Get match100, match95, ...
    db_1row matrix_select "
	select	m.*
	from		im_trans_trados_matrix m
	where	m.object_id = :project_id
    and     m.task_type = :task_type
    "

    set matrix(x) $match_x
    set matrix(rep) $match_rep
    set matrix(perf) $match_perf
    set matrix(cfr) $match_cfr
    set matrix(100) $match100
    set matrix(95) $match95
    set matrix(85) $match85
    set matrix(75) $match75
    set matrix(50) $match50
    set matrix(0) $match0

    set matrix(f95) $match_f95
    set matrix(f85) $match_f85
    set matrix(f75) $match_f75
    set matrix(f50) $match_f50

    set matrix(locked) $locked

    set matrix(type) project
    set matrix(object) $project_id

    return [array get matrix]
}


ad_proc -public im_trans_trados_matrix_company { 
    {-task_type "trans"}
    company_id 
} {
    Returns an array with the trados matrix values for a company.
} {
    ns_log NOTICE "intranet-trans-procs::im_trans_trados_matrix_company: Entering ..."
    set count [db_string matrix_count "select count(*) from im_trans_trados_matrix where object_id=:company_id and task_type = :task_type"]
    if {!$count} { 
        	ns_log NOTICE "intranet-trans-procs::im_trans_trados_matrix_company: No entries found in table im_trans_trados_matrix, now calling im_trans_trados_matrix_internal"
        	set provider_p [db_string provide_p "select 1 from im_companies where company_id = :company_id and company_type_id in ([template::util::tcl_to_sql_list [im_sub_categories [im_company_type_provider]]])" -default 0]
        	if {$provider_p} {
            	return [im_trans_trados_matrix_internal -task_type $task_type -provider]
        	} else {
            	return [im_trans_trados_matrix_internal -task_type $task_type]            	
        	}

    }

    # Get match100, match95, ...
    db_1row matrix_select "
    select	m.*
	    from		im_trans_trados_matrix m
	    where	m.object_id = :company_id
	    and     m.task_type = :task_type
	    "

    set matrix(x) $match_x
    set matrix(rep) $match_rep
    set matrix(perf) $match_perf
    set matrix(cfr) $match_cfr
    set matrix(100) $match100
    set matrix(95) $match95
    set matrix(85) $match85
    set matrix(75) $match75
    set matrix(50) $match50
    set matrix(0) $match0

    set matrix(f95) $match_f95
    set matrix(f85) $match_f85
    set matrix(f75) $match_f75
    set matrix(f50) $match_f50

    set matrix(locked) $locked

    set matrix(type) company
    set matrix(object) $company_id

    return [array get matrix]
}

ad_proc -public im_trans_trados_matrix_internal {
    {-task_type "trans"}
    -provider:boolean
} {
    Returns an array with the trados matrix values for the "Internal" company.
} {

    ns_log NOTICE "intranet-trans-procs::im_trans_trados_matrix_internal: Entering im_trans_trados_matrix_internal"

    if {$provider_p} {
        set company_id [im_company_freelance]
    } else {
        set company_id [im_company_internal]
    }

    
    set count [db_string matrix_count "select count(*) from im_trans_trados_matrix where object_id=:company_id and task_type = :task_type"]
    if {!$count} { 
        	ns_log NOTICE "intranet-trans-procs::im_trans_trados_matrix_internal: No entries in table im_trans_trados_matrix found for company_id: company_id, calling im_trans_trados_matrix_default"
        	return [im_trans_trados_matrix_default] 
    }

    # Get match100, match95, ...
    db_1row internal_matrix_select "
	select	m.*
	from		im_trans_trados_matrix m
	where	m.object_id = :company_id
		and m.task_type = :task_type
    "

    set matrix(x) $match_x
    set matrix(rep) $match_rep
    set matrix(perf) $match_perf
    set matrix(cfr) $match_cfr
    set matrix(100) $match100
    set matrix(95) $match95
    set matrix(85) $match85
    set matrix(75) $match75
    set matrix(50) $match50
    set matrix(0) $match0
    set matrix(f95) $match_f95
    set matrix(f85) $match_f85
    set matrix(f75) $match_f75
    set matrix(f50) $match_f50
    set matrix(locked) $locked
    set matrix(type) internal
    set matrix(object) 0
    return [array get matrix]
}


ad_proc -public im_trans_trados_matrix_default { } {
    Returns an array with the trados matrix values for the "Internal" company.
} {
    ns_log NOTICE "intranet-trans-procs.tcl::im_trans_trados_matrix_default: Returning default matrix"
    set matrix(x) 0.25
    set matrix(rep) 0.25
    set matrix(perf) 0.25
    set matrix(cfr) 0.25
    set matrix(100) 0.25
    set matrix(95) 0.3
    set matrix(85) 0.5
    set matrix(75) 1.0
    set matrix(50) 1.0
    set matrix(0) 1.0
    set matrix(f95) 0.3
    set matrix(f85) 0.5
    set matrix(f75) 1.0
    set matrix(f50) 1.0
    set matrix(locked) 1.0
    set matrix(type) default
    set matrix(object) 0

    return [array get matrix]
}


# -------------------------------------------------------------------
# Permissions
# -------------------------------------------------------------------


ad_proc -public im_translation_task_permissions {user_id task_id view_var read_var write_var admin_var} {
    Fill the "by-reference" variables read, write and admin
    with the permissions of $user_id on $project_id

    Allow to download the file if the user is an admin, a project admin
    or an employee of the company. Or if the user is an translator, editor,
    proofer or "other" of the specified task.
} {
    upvar $view_var view
    upvar $read_var read
    upvar $write_var write
    upvar $admin_var admin

    set view 0
    set read 0
    set write 0
    set admin 0

    set project_id [db_string project_id "select project_id from im_trans_tasks where task_id = :task_id"]

    set user_is_admin_p [im_is_user_site_wide_or_intranet_admin $user_id]
    set user_is_wheel_p [im_profile::member_p -profile_id [im_wheel_group_id] -user_id $user_id]
    set user_is_group_member_p [im_biz_object_member_p $user_id $project_id]
    set user_is_group_admin_p [im_biz_object_admin_p $user_id $project_id]
    set user_is_employee_p [im_user_is_employee_p $user_id]

    if {$user_is_admin_p} { set admin 1}
    if {$user_is_wheel_p} { set admin 1}
    if {$user_is_group_member_p} { set read 1}
    if {$user_is_group_admin_p} { set admin 1}

    if {$admin} {
	set read 1
	set write 1
    }
    if ($read) { set view 1 }
}


# -------------------------------------------------------------------
# Drop-Down Components
# -------------------------------------------------------------------

ad_proc im_task_user_select {
    {-source_language_id 0}
    {-target_language_id 0}
    {-group_list {}}
    -auto_assign:boolean
	-with_no_change:boolean
    select_name 
    user_list 
    default_user_id 
    {role ""}
} {
    Return a formatted HTML drop-down select component with the
    list of members of the current project.
} {
	ns_log Debug "default_user_id=$default_user_id"
    set select_html "<select name='$select_name'>\n"
    if {"" == $default_user_id} {
		if {$with_no_change_p} {
			# Append a "no_change" value
			append select_html "<option value='no_change' selected>[_ intranet-translation.No_Change]</option>\n"		
			append select_html "<option value=''>[_ intranet-translation.Remove_Assignment]</option>\n"
		} else {	
			append select_html "<option value='' selected>[_ intranet-translation.--_Please_Select_--]</option>\n"
		}
    } else {
		append select_html "<option value=''>[_ intranet-translation.--_Please_Select_--]</option>\n"
    }

    # Check if the filtering option is enabled or not.
    set source_target_select_p [ad_parameter -package_id [im_package_translation_id] EnableTaskAssignmentBasedOnSourceTargetLanguageP "" 0]
    if {!$source_target_select_p} {
       set source_language_id 0
       set target_language_id 0
    }

    # Deal with task specific resource - only show the guys who match
    # the source- and target language
    if {0 != $source_language_id} {
        set source_language [im_category_from_id $source_language_id]
		set source_language_uids [util_memoize [list db_list source_lang_uids "
			select	user_id
			from 	im_freelance_skills fs,
			im_categories sl
			where	fs.skill_id = sl.category_id and
			skill_type_id in (select category_id from im_categories where category = 'Source Language') and
			-- only compare the first two letter of the source language
			lower(substring(sl.category from 1 for 2)) = lower(substring('$source_language' from 1 for 2))
	"] 60]
    }

    if {0 != $target_language_id} {
        set target_language [im_category_from_id $target_language_id]
		set target_language_uids [util_memoize [list db_list target_lang_uids "
			select	user_id
			from		im_freelance_skills fs,
			im_categories sl
			where	fs.skill_id = sl.category_id and
			skill_type_id in (select category_id from im_categories where category = 'Target Language') and
			-- only compare the first two letter of the target language
			lower(substring(sl.category from 1 for 2)) = lower(substring('$target_language' from 1 for 2))
		"] 60]
    }
    

	set matched_user_ids [list]
    foreach user_list_entry $user_list {
		set user_id [lindex $user_list_entry 0]
		set user_name [lindex $user_list_entry 1]
		
		if {0 != $source_language_id} {
	    		if {[lsearch $source_language_uids $user_id] < 0} { continue }
		}
		if {0 != $target_language_id} {
	    		if {[lsearch $target_language_uids $user_id] < 0} { continue }
		}

		lappend matched_user_ids $user_id
		set username($user_id) $user_name
	}
	
	if {[llength $matched_user_ids] == 1} {
		set user_id [lindex $matched_user_ids 0]
		set selected ""
		if {$auto_assign_p || $default_user_id == $user_id} {set selected "selected"}
		append select_html "<option value='$user_id' $selected>$username($user_id)</option>\n"
	} else {
		foreach user_id $matched_user_ids {
			set selected ""
			if {$default_user_id == $user_id} { set selected "selected"}
			append select_html "<option value='$user_id' $selected>$username($user_id)</option>\n"
		}
	}

    	if {[llength $group_list] > 0} {
		append select_html "<option value=''></option>\n"
	}

    foreach group_list_entry $group_list {
		set group_id [lindex $group_list_entry 0]
		set group_name [lindex $group_list_entry 1]
		set selected ""
		if {$default_user_id == $group_id} { set selected "selected"}
		append select_html "<option value='$group_id' $selected>$group_name</option>\n"
    }

    append select_html "</select>\n"
    return $select_html
}




ad_proc im_trans_language_select {
    {-translate_p 0}
    {-include_empty_p 1}
    {-include_empty_name "--_Please_select_--"}
    {-include_country_locale 0}
    {-locale ""}
    select_name
    { default "" }
} {
    set bind_vars [ns_set create]
    set category_type "Intranet Translation Language"
    ns_set put $bind_vars category_type $category_type

    set country_locale_sql ""
    if {!$include_country_locale} {
	set country_locale_sql "and length(category) < 5"
    }

    set sql "
        select *
        from
                (select
                        category_id,
                        category,
                        category_description
                from
                        im_categories
                where
			(enabled_p = 't' OR enabled_p is NULL) and
                        category_type = :category_type
			$country_locale_sql
                ) c
        order by lower(category)
    "

    return [im_selection_to_select_box -translate_p $translate_p -locale $locale -include_empty_p $include_empty_p -include_empty_name $include_empty_name $bind_vars category_select $sql $select_name $default]
}


ad_proc -public im_target_languages { project_id} {
    Returns a (possibly empty list) of target languages 
    (i.e. "en_ES", ...) used for a specific project or task
} {
    set result [list]
    set sql "
select
	im_category_from_id(l.language_id) as target_language
from 
	im_target_languages l
where 
	project_id=:project_id
"
    db_foreach select_target_languages $sql {
	lappend result $target_language
    }
    return $result
}


ad_proc -public im_target_language_ids { project_id} {
    Returns a (possibly empty list) of target language IDs used
} {
    set result [list]
    set sql "
	select	language_id
	from	im_target_languages
	where	project_id=:project_id
    "
    db_foreach select_target_languages $sql {
	lappend result $language_id
    }
    return $result
}


ad_proc -public im_trans_project_details_component { user_id project_id return_url } {
    Return a formatted HTML widget showing the translation
    specific fields of a translation project.
} {
    # Is this a translation project?
    if {![im_project_has_type $project_id "Translation Project"] || ![im_permission $user_id view_trans_proj_detail]} {
	return ""
    }

    im_project_permissions $user_id $project_id view read write admin

    set query "
	select	p.*,
		im_name_from_user_id(p.company_contact_id) as company_contact_name
	from	im_projects p
	where	p.project_id=:project_id
    "

    if { ![db_0or1row projects_info_query $query] } {
	ad_return_complaint 1 "[_ intranet-translation.lt_Cant_find_the_project_1]"
	return
    }

    set html "
	  <tr> 
	    <td colspan=2 class=rowtitle align=middle>
	      [_ intranet-translation.Project_Details]
	    </td>
	  </tr>
    "

    append html "
	  <tr> 
	    <td>[_ intranet-translation.Client_Project]</td>
	    <td>$company_project_nr</td>
	  </tr>
	  <tr> 
	    <td>[_ intranet-translation.Final_User]</td>
	    <td>$final_company</td>
	  </tr>
	  <tr> 
	    <td>[_ intranet-translation.Quality_Level]</td>
	    <td>[im_category_from_id $expected_quality_id]</td>
	  </tr>
    "

    set company_contact_html [im_render_user_id $company_contact_id $company_contact_name $user_id $project_id]
    if {"" != $company_contact_html} {
	append html "
	  <tr> 
	    <td>[_ intranet-translation.Company_Contact]</td>
	    <td>$company_contact_html</td>
	  </tr>
	"
    }

    append html "
	  <tr> 
	    <td>[_ intranet-translation.Subject_Area]</td>
	    <td>[im_category_from_id $subject_area_id]</td>
	  </tr>
	  <tr> 
	    <td>[_ intranet-translation.Source_Language]</td>
	    <td>[im_category_from_id $source_language_id]</td>
	  </tr>
	  <tr> 
	    <td>[_ intranet-translation.Target_Languages_1]</td>
	    <td>[im_target_languages $project_id]</td>
	  </tr>
    "

    if {$write} {
	append html "
	  <tr> 
	    <td></td>
	    <td>
	<form action=/intranet-translation/projects/edit-trans-data method=POST>
	[export_form_vars project_id return_url]
	<input type=submit name=edit value=\"[lang::message::lookup "" intranet-translation.Edit_Button "Edit"]\">
	</form>
	    </td>
	  </tr>
	"
    }

    # Check if there are menus related to translation visible for the current user
    # Add the <ul>-List of associated menus
    set bind_vars [list user_id $user_id]
    set menu_html [im_menu_ul_list -no_cache "reporting-translation" $bind_vars]
    if {"" != $menu_html} {
	append html "
	<tr>
	    <td colspan=2>&nbsp;</td>
	</tr>
	<tr>
	    <td colspan=2 class=rowtitle align=middle>
		[lang::message::lookup "" intranet-translation.Associated_reports "Associated Reports"]
	    </td>
	</tr>
	<tr>
	    <td colspan=2>
		$menu_html
	    </td>
	</tr>
	"
    }

    return "
	<table cellpadding=0 cellspacing=2 border=0>
	$html
	</table>
    "
}


# -------------------------------------------------------------------
# Status Engine for im_trans_tasks
#
#    340 Created  
#    342 for Trans
#    344 Trans-ing 
#    346 for Edit  
#    348 Editing  
#    350 for Proof  
#    352 Proofing  
#    354 for QCing  
#    356 QCing  
#    358 for Deliv  
#    360 Delivered  
#    365 Invoiced  
#    370 Payed  
#    372 Deleted 
# -------------------------------------------------------------------

# Update the task to advance to the next status
# after a successful upload of the related file
ad_proc im_trans_upload_action {
    {-upload_file "" }
    task_id 
    task_status_id 
    task_type_id 
    user_id
} {
} {
    set new_status_id $task_status_id

    switch $task_status_id {
	340 { 
	    # Created: Maybe in the future there maybe a step between
	    # created and "for Trans", but today it's the same.

	    # there shouldn't be any upload...
	}
	342 { # for Trans: 
	}
	344 { # Translating: 
	    if {$task_type_id == [im_project_type_trans]} {
		# we are done, because this task is translation only.
		set new_status_id 358
	    } else {
		set new_status_id 346
	    }
	}
	346 { # for Edit: 
	}
	348 { # Editing: 
	    if {$task_type_id == [im_project_type_edit] || $task_type_id == [im_project_type_trans_edit] || $task_type_id == [im_project_type_trans_spot]} {
		# we are done, because this task is only until editing
		# (spotcheck = short editing)
		set new_status_id 358
	    } else {
		set new_status_id 350
	    }
	}
	350 { # for Proof: 
	}
	352 { # Proofing: 
	    # All types are done when proofed.
	    set new_status_id 358
	}
	default {
	}
    }

    ns_log Debug "im_trans_upload_action task_id=$task_id task_status_id=$task_status_id task_type_id=$task_type_id user_id=$user_id => $new_status_id"

    # only update if there was a change...
    if {$new_status_id != $task_status_id} {

	db_dml advance_status "
		update im_trans_tasks 
		set task_status_id=:new_status_id 
		where task_id=:task_id
	"

	# Successfully modified translation task
	# Call user_exit to let TM know about the event
	if {358 == $new_status_id} {
	    im_user_exit_call trans_task_complete $task_id
	} else {
	    im_user_exit_call trans_task_update $task_id
	}
	im_audit -object_type im_trans_task -action after_update -object_id $task_id -status_id $new_status_id -type_id $task_type_id

    }

    # Always register the user-action
    set upload_action_id [db_string upload_action_id "select category_id from im_categories where category_type='Intranet File Action Type' and lower(category)='upload'" -default ""]
    set action_id [db_nextval im_task_actions_seq]
    set sysdate [db_string sysdate "select sysdate from dual"]
    db_dml register_action "insert into im_task_actions (
		action_id,
		action_type_id,
		user_id,
		task_id,
		action_date,
		old_status_id,
		new_status_id
	    ) values (
		:action_id,
		$upload_action_id,
		:user_id,
		:task_id,
		:sysdate,
		:task_status_id,
		:new_status_id
    )"

    # Register the new filename as a valid one
    if {"" != $upload_file} {
        if {[catch {
            db_dml update_task_action_file "
                update im_task_actions set
                        upload_file = :upload_file
                where action_id = :action_id
            "
        } err_msg]} {
            ns_log Error "im_trans_upload_action: Error updating im_task_actions: $err_msg"
        }
    }

}


# Update the task to advance to the next status
# after a successful download of the related file
ad_proc im_trans_download_action {task_id task_status_id task_type_id user_id} {
} {

    set new_status_id $task_status_id

    switch $task_status_id {
	340 { 
	    # Created: Maybe in the future there maybe a step between
	    # created and "for Trans", but today it's the same.
	    switch $task_type_id {
		88 {
		    set new_status_id 348
		}
		95 {
		    set new_status_id 352
		}
		default {
		    set new_status_id 344
		}
	    }
	}
	342 { # for Trans: 
	    set new_status_id 344
	}
	344 { # Translating: 
	}
	346 { # for Edit: 
	    set new_status_id 348
	}
	348 { # Editing: 
	}
	350 { # for Proof: 
	    set new_status_id 352
	}
	352 { # Proofing: 
	}
	default {
	}
    }

    ns_log Debug "im_trans_download_action task_id=$task_id task_status_id=$task_status_id task_type_id=$task_type_id user_id=$user_id => $new_status_id"

    # only update if there was a change...
    if {$new_status_id != $task_status_id} {

	db_dml advance_status "
		update im_trans_tasks 
		set task_status_id=:new_status_id 
		where task_id=:task_id
	"

        # Successfully modified translation task
        # Call user_exit to let TM know about the event
        im_user_exit_call trans_task_update $task_id
	im_audit -object_type im_trans_task -action after_update -object_id $task_id -status_id $new_status_id -type_id $task_type_id

    }

    # Always register the user-action
    set download_action_id [db_string upload_action_id "select category_id from im_categories where category_type='Intranet File Action Type' and lower(category)='download'" -default ""]
    set action_id [db_nextval im_task_actions_seq]
    db_dml register_action "insert into im_task_actions (
		action_id,
		action_type_id,
		user_id,
		task_id,
		action_date,
		old_status_id,
		new_status_id
	    ) values (
		:action_id,
		$download_action_id,
		:user_id,
		:task_id,
		now(),
		:task_status_id,
		:new_status_id
    )"
}




ad_proc im_task_workflow_translate_role {
    role
} {
    Returns a translation for the role.
} {
    set trans_l10n [lang::message::lookup "" intranet-translation.wf_role_trans "Translator"]
    set edit_l10n [lang::message::lookup "" intranet-translation.wf_role_edit "Editor"]
    set proof_l10n [lang::message::lookup "" intranet-translation.wf_role_proof "Proof Reader"]
    set other_l10n [lang::message::lookup "" intranet-translation.wf_role_other "Other"]

    switch $role {
            trans { return $trans_l10n }
            edit { return $edit_l10n }
            proof { return $proof_l10n }
            other { return $other_l10n }
    }
    return ""
}

ad_proc im_task_next_workflow_role {
    {-translate_p 1}
    task_id
} {
    Returns the next workflow role ("Translator" "Editor" "Proof Reader"),
    depending on the current task statusl.

    Example: the task is in status "translating", then this procedure
    returns "Editor". Or during editing, it returns "Proof Reader".

    At the end of the WF chain an empty string  "" is returned to indicate
    that there is no next workflow state.
#         340 | Created
#         342 | for Trans
#         344 | Trans-ing
#         346 | for Edit
#         348 | Editing
#         350 | for Proof
#         352 | Proofing
#         354 | for QCing
#         356 | QCing
#         358 | for Deliv
#         360 | Delivered
#         365 | Invoiced
#         370 | Payed
#         372 | Deleted


} {
    # get everything about the task
    set task_status_id [db_string task_status "
        select  t.task_status_id
        from    im_trans_tasks t
        where   t.task_id=:task_id
    " -default 0]

    set role ""
    switch $task_status_id {
        340 { set role edit }
        342 { set role edit }
        344 { set role edit }
        346 { set role edit }
        348 { set role proof }
        350 { set role "" }
        352 { set role "" }
        354 { set role "" }
        356 { set role "" }
    }

    if {$translate_p} {
        set role [im_task_workflow_translate_role $role]
    }

    return $role
}


ad_proc im_task_previous_workflow_role {
    {-translate_p 1}
    task_id
} {
    Returns the previous workflow role ("Translator" "Editor" "Proof Reader"),
    depending on the current task statusl.

    Example: the task is in status "editing", then this procedure
    returns "Translator". Or during proof reading, it returns "Editor".

    During translation, an empty string  "" is returned to indicate that
    there was no previous workflow state.

#         340 | Created
#         342 | for Trans
#         344 | Trans-ing
#         346 | for Edit
#         348 | Editing
#         350 | for Proof
#         352 | Proofing
#         354 | for QCing
#         356 | QCing
#         358 | for Deliv
#         360 | Delivered
#         365 | Invoiced
#         370 | Payed
#         372 | Deleted

} {
    # get everything about the task
    set task_status_id [db_string task_status "
        select  t.task_status_id
        from    im_trans_tasks t
        where   t.task_id=:task_id
    " -default 0]

    set role ""
    switch $task_status_id {
        340 { set role "" }
        342 { set role "" }
        344 { set role "" }
        346 { set role trans }
        348 { set role trans }
        350 { set role edit }
        352 { set role edit }
        354 { set role edit }
        356 { set role edit }
    }

    if {$translate_p} {
        set role [im_task_workflow_translate_role $role]
    }

    return $role
}



ad_proc im_task_previous_workflow_stage_user {
    task_id
} {
    Returns the user who owned the previous workflow state.
    Example: the task is in status "editing", then this procedure
    returns the user_id of the translator. Or during proof reading,
    it returns the user_id of the editor.
    During translation, a "0" is returned to indicate that there
    was no previous workflow state.
} {
    set trans_id 0
    set edit_id 0
    set proof_id 0

    # get everything about the task
    set task_sql "
        select  t.*
        from    im_trans_tasks t
        where   t.task_id=:task_id
    "
    db_0or1row task_info $task_sql

    set prev_role [im_task_previous_workflow_role -translate_p 0 $task_id]
    set user_id 0
    switch $prev_role {
        "trans" { set user_id $trans_id }
        "edit" { set user_id $edit_id }
        "proof" { set user_id $proof_id }
    }

    if {"" == $user_id} { set user_id 0 }
    return $user_id
}




ad_proc im_task_next_workflow_stage_user {
    task_id
} {
    Returns the user who owns the next workflow state.
    Example: the task is in status "translating", then this procedure
    returns the user_id of the editor.
    During the last WF stage a "0" is returned to indicate that there
    was no next workflow state.
} {
    set trans_id 0
    set edit_id 0
    set proof_id 0

    # get everything about the task
    set task_sql "
        select  t.*
        from    im_trans_tasks t
        where   t.task_id=:task_id
    "
    db_0or1row task_info $task_sql

    set next_role [im_task_next_workflow_role -translate_p 0 $task_id]
    set user_id 0
    switch $next_role {
        "trans" { set user_id $trans_id }
        "edit" { set user_id $edit_id }
        "proof" { set user_id $proof_id }
    }

    if {"" == $user_id} { set user_id 0 }
    return $user_id
}


ad_proc im_task_component_upload {
    user_id
    user_admin_p
    task_status_id
    task_type_id
    source_language
    target_language
    trans_id
    edit_id
    proof_id
    other_id
} {
    Determine if the user $user_id is allows to upload a file in the current
    status of a task.
    Returns a list composed by:
    1. the folder for download or ""
    2. the folder for upload or "" and
    3. a message for the user
} {
    ns_log Debug "im_task_component_upload(user_id=$user_id user_admin_p=$user_admin_p task_status_id=$task_status_id task_type_id=$task_type_id target_language=$target_language trans_id=$trans_id edit_id=$edit_id proof_id=$proof_id other_id=$other_id)"

    # Localize the workflow stage directories
    set locale "en_US"
    set source [lang::message::lookup $locale intranet-translation.Workflow_source_directory "source"]
    set trans [lang::message::lookup $locale intranet-translation.Workflow_trans_directory "trans"]
    set edit [lang::message::lookup $locale intranet-translation.Workflow_edit_directory "edit"]
    set proof [lang::message::lookup $locale intranet-translation.Workflow_proof_directory "proof"]
    set deliv [lang::message::lookup $locale intranet-translation.Workflow_deliv_directory "deliv"]
    set other [lang::message::lookup $locale intranet-translation.Workflow_other_directory "other"]


    # Download
    set msg_please_download_source [lang::message::lookup "" intranet-translation.Please_download_the_source_file "Please download the source file"]
    set msg_please_download_translated [lang::message::lookup "" intranet-translation.Please_download_the_translated_file "Please download the translated file"]
    set msg_please_download_edited [lang::message::lookup "" intranet-translation.Please_download_the_edited_file "Please download the edited file"]

    # Translation
    set msg_ready_to_be_trans_by_other [lang::message::lookup "" intranet-translation.The_file_is_ready_to_be_trans_by_other "The file is ready to be translated by another person."]
    set msg_file_translated_by_other [lang::message::lookup "" intranet-translation.The_file_is_trans_by_another_person "The file is being translated by another person"]
    set msg_please_upload_translated [lang::message::lookup "" intranet-translation.Please_upload_the_translated_file "Please upload the translated file"]

    # Edit
    set msg_please_upload_the_edited_file [lang::message::lookup "" intranet-translation.Please_upload_the_edited_file "Please upload the edited file"]
    set msg_you_are_allowed_to_upload_again [lang::message::lookup "" intranet-translation.You_are_allowed_to_upload_again "You are allowed to upload the file again while the Editor has not started editing yet..."]
    set msg_file_is_ready_to_be_edited_by_other [lang::message::lookup "" intranet-translation.File_is_ready_to_be_edited_by_other "The file is ready to be edited by another person"]
    set msg_file_is_being_edited_by_other [lang::message::lookup "" intranet-translation.File_is_being_edited_by_other "The file is being edited by another person"]

    # Proof
    set msg_please_upload_the_proofed_file [lang::message::lookup "" intranet-translation.Please_upload_the_proofed_file "Please upload the proofed file"]
    set msg_upload_again_while_proof_reader_hasnt_started [lang::message::lookup "" intranet-translation.You_can_upload_again_while_proof_reader_hasnt_started "You are allowed to upload the file again while the Proof Reader has not started editing yet..."]
    set msg_file_is_ready_to_be_proofed_by_other [lang::message::lookup "" intranet-translation.File_is_ready_to_be_proofed_by_other "The file is ready to be proofed by another person"]


    # Other
    set msg_you_are_the_admin [lang::message::lookup "" intranet-translation.You_are_the_admin "You are the administrator..."]

    switch $task_status_id {
	340 { # Created:
	    # The user is admin, so he may upload/download the file
	    if {$user_admin_p} {
		return [list "${source}_$source_language" "${source}_$source_language" $msg_you_are_the_admin]
	    }

	    # Created: In the future there maybe a step between
	    # created and "for Trans", but today it's the same.

	    if {$user_id == $trans_id } {
		return [list "${source}_$source_language" "" $msg_please_download_source]
	    } 

	    # User should also be allowed to upload/download file when Project Type is 'EDIT ONLY' or 'PROOF ONLY'
	    # fraber: Fixed error by KH
	    if {$task_type_id == 88 || $task_type_id == 95} {
		if { $user_id == $edit_id || $user_id == $proof_id} {
		    return [list "${source}_$source_language" "" $msg_please_download_source]
		} 
		
		# User should also be allowed to upload/download file when Project Type is 'EDIT ONLY' or 'PROOF ONLY'
		if { $user_id == $edit_id || $user_id == $proof_id} {
		    return [list "${source}_$source_language" "" $msg_please_download_source]
		}
	    }

	    if {"" != $trans_id} {
		return [list "" "" $msg_ready_to_be_trans_by_other]
	    }
	    return [list "" "" ""]

	}
	342 { # for Trans: 
	    if {$user_id == $trans_id} {
		return [list "${source}_$source_language" "" $msg_please_download_source]
	    }
	    if {"" != $trans_id} {
		return [list "" "" $msg_ready_to_be_trans_by_other]
	    }
	    return [list "" "" ""]
	}
	344 { # Translating: Allow to upload a file into the trans folder
	    if {$user_id == $trans_id} {
		return [list "${source}_$source_language" "${trans}_$target_language" $msg_please_upload_translated]
	    } else {
		return [list "" "" $msg_file_translated_by_other]
	    }
	}
	346 { # for Edit: 
	    if {$user_id == $edit_id} {
		return [list "${trans}_$target_language" "" $msg_please_download_translated]
	    }
	    if {$user_id == $trans_id} {
		# The translator may upload the file again, while the Editor has not
		# downloaded the file yet.
		return [list "" "${trans}_$target_language" $msg_you_are_allowed_to_upload_again]
	    } else {
		return [list "" "" $msg_file_is_ready_to_be_edited_by_other]
	    }
	}
	348 { # Editing: Allow to upload a file into the edit folder
	    if {$user_id == $edit_id} {
		return [list "${trans}_$target_language" "${edit}_$target_language" $msg_please_upload_the_edited_file]
	    } else {
		return [list "" "" $msg_file_is_being_edited_by_other]
	    }
	}
	350 { # for Proof: 
	    if {$user_id == $proof_id} {
		return [list "${edit}_$target_language" "" $msg_please_download_edited]
	    }
	    if {$user_id == $edit_id} {
		# The editor may upload the file again, while the Proofer has not
		# downloaded the file yet.
		return [list "" "${edit}_$target_language" $msg_upload_again_while_proof_reader_hasnt_started]
	    } else {
		return [list "" "" $msg_file_is_ready_to_be_proofed_by_other]
	    }
	}
	352 { # Proofing: Allow to upload a file into the proof folder
	    if {$user_id == $proof_id} {
		return [list "${edit}_$target_language" "${proof}_$target_language" $msg_please_upload_the_proofed_file]
	    } else {
		return [list "" "" $msg_file_is_ready_to_be_proofed_by_other]
	    }
	}
	default {
	    return [list "" "" ""]
	}
    }
}


# -------------------------------------------------------------------
# Calculate Project Advance
# -------------------------------------------------------------------

ad_proc im_trans_task_project_advance { project_id } {
    Calculate the percentage of advance of the project.
} {
    set automatic_advance_p [ad_parameter -package_id [im_package_translation_id] AutomaticProjectAdvanceP "" 1]
    if {!$automatic_advance_p} {
	return ""
    }

    set advance ""
    if {[im_table_exists im_trans_task_progress]} {
	set advance [db_string project_advance "
	    select
		sum(volume_completed) / (0.000001 + sum(volume)) * 100 as percent_completed
	    from
		(select
			t.task_id,
			t.task_units,
			uom_weights.weight,
			ttp.percent_completed as perc,
			t.task_units * uom_weights.weight * ttp.percent_completed as volume_completed,
			t.task_units * uom_weights.weight * 100 as volume,
			im_category_from_id(t.task_uom_id) as task_uom,
			im_category_from_id(t.task_type_id) as task_type,
			im_category_from_id(t.task_status_id) as task_status
		from
			im_trans_tasks t,
			im_trans_task_progress ttp,
			(       select  320 as id, 1.0 as weight UNION
				select  321 as id, 8.0 as weight UNION
				select  322 as id, 0.0 as weight UNION
				select  323 as id, 1.0 as weight UNION
				select  324 as id, 0.0032 as weight UNION
				select  325 as id, 0.0032 as weight UNION
				select  326 as id, 0.016 as weight UNION
				select  327 as id, 0.016 as weight
			) uom_weights
		where
			t.project_id = :project_id
			and t.task_type_id = ttp.task_type_id
			and t.task_status_id = ttp.task_status_id
			and t.task_uom_id = uom_weights.id
		) volume
	"]
    }

    if {"" != $advance} {
	db_dml update_project_advance "
		update im_projects
		set percent_completed = :advance
		where project_id = :project_id
	"

	# Write audit trail
	im_project_audit -project_id $project_id

    }

    # "Escalate" to super-projects and mixed translation/consulting projects
    catch {
	im_timesheet_project_advance $project_id
    }


    return $advance
}
	
# -------------------------------------------------------------------
# Task Status Component
# -------------------------------------------------------------------

ad_proc im_task_status_component { user_id project_id return_url } {
    Returns a formatted HTML component, representing a summary of
    the current project.
    The table shows for each participating user how many files have
    been 1. assigned to the user, 2. downloaded by the user and
    3. uploaded by the user.
    File movements outside the translation workflow (moving files
    in the filesystem) are not reflected by this component (yet).
} {
    ns_log Debug "im_trans_status_component($user_id, $project_id)"
    set current_user_id [ad_get_user_id]
    set current_user_is_employee_p [expr [im_user_is_employee_p $current_user_id] | [im_is_user_site_wide_or_intranet_admin $current_user_id]]

    # Is this a translation project?
    if {![im_project_has_type $project_id "Translation Project"]} {
	ns_log Debug "im_task_status_component: Project $project_id is not a translation project"
	return ""
    }

    im_project_permissions $current_user_id $project_id view read write admin
    if {![im_permission $current_user_id view_trans_task_status]} {
	return ""
    }

    set bgcolor(0) " class=roweven"
    set bgcolor(1) " class=rowodd"

    set up [db_string upload_action_id "select category_id from im_categories where category_type='Intranet File Action Type' and lower(category)='upload'" -default ""]
    set down [db_string download_action_id "select category_id from im_categories where category_type='Intranet File Action Type' and lower(category)='download'" -default ""]

    # ------------------Display the list of current tasks...-------------

    set task_status_html "
<form action=/intranet-translation/trans-tasks/task-action method=POST>
[export_form_vars project_id return_url]

<table cellpadding=0 cellspacing=2 border=0>
<tr>
  <td class=rowtitle align=center colspan=17>
    [_ intranet-translation.lt_Project_Workflow_Stat]
[im_gif -translate_p 1 help "Shows the status of all tasks\nAss: Assigned Files\nDn: Downloaded Files\nUp: Uploaded Files"]
  </td>
</tr>
<tr>
  <td class=rowtitle align=center rowspan=2>[_ intranet-translation.Name]</td>
  <td class=rowtitle align=center colspan=3>[_ intranet-translation.Translation]</td>
  <td class=rowtitle align=center colspan=3>[_ intranet-translation.Editing]</td>
  <td class=rowtitle align=center colspan=3>[_ intranet-translation.Proofing]</td>
  <td class=rowtitle align=center colspan=3>[_ intranet-translation.Other]</td>
  <td class=rowtitle align=center colspan=3>[_ intranet-translation.Wordcount]</td>
</tr>
<tr>
  <td class=rowtitle align=center>[_ intranet-translation.Ass]</td>
  <td class=rowtitle align=center>[_ intranet-translation.Dn]</td>
  <td class=rowtitle align=center>[_ intranet-translation.Up]</td>
  <td class=rowtitle align=center>[_ intranet-translation.Ass]</td>
  <td class=rowtitle align=center>[_ intranet-translation.Dn]</td>
  <td class=rowtitle align=center>[_ intranet-translation.Up]</td>
  <td class=rowtitle align=center>[_ intranet-translation.Ass]</td>
  <td class=rowtitle align=center>[_ intranet-translation.Dn]</td>
  <td class=rowtitle align=center>[_ intranet-translation.Up]</td>
  <td class=rowtitle align=center>[_ intranet-translation.Ass]</td>
  <td class=rowtitle align=center>[_ intranet-translation.Dn]</td>
  <td class=rowtitle align=center>[_ intranet-translation.Up]</td>

  <td class=rowtitle align=center>[_ intranet-translation.Trans]</td>
  <td class=rowtitle align=center>[_ intranet-translation.Edit]</td>
  <td class=rowtitle align=center>[_ intranet-translation.Proof]</td>
</tr>\n"

    # ------------------- Get the number of tasks to assign----------------
    # This SQL calculates the overall number of files/wordcounts to be
    # assigned. We are going to subtract the assigned files/wcs from it.

    set unassigned_files_sql "
	select
		count(t.trans) as unassigned_trans,
		count(t.edit) as unassigned_edit,
		count(t.proof) as unassigned_proof,
		count(t.other) as unassigned_other,
		CASE WHEN sum(t.trans) is null THEN 0 ELSE sum(t.trans) END as unassigned_trans_wc,
		CASE WHEN sum(t.edit) is null THEN 0 ELSE sum(t.edit) END as unassigned_edit_wc,
		CASE WHEN sum(t.proof) is null THEN 0 ELSE sum(t.proof) END as unassigned_proof_wc,
		CASE WHEN sum(t.other) is null THEN 0 ELSE sum(t.other) END as unassigned_other_wc
	from
		(select
			t.task_type_id,
			CASE WHEN t.task_type_id in (87,89,94) THEN t.task_units END as trans,
			CASE WHEN t.task_type_id in (87,88,89,94) THEN t.task_units  END as edit,
			CASE WHEN t.task_type_id in (89,95) THEN t.task_units  END as proof,
			CASE WHEN t.task_type_id in (85,86,90,91,92,96) THEN t.task_units END as other
		from
			im_trans_tasks t
		where
			t.project_id = :project_id
		) t
    "

    db_1row unassigned_totals $unassigned_files_sql

    # ----------------------Get task status ------------------------------

    # Aggregate the information from the inner_sql and 
    # order it by user
    set task_status_sql "
	select
		u.user_id,
		sum(trans_down) as trans_down,
		sum(trans_up) as trans_up,
		sum(edit_down) as edit_down,
		sum(edit_up) as edit_up,
		sum(proof_down) as proof_down,
		sum(proof_up) as proof_up,
		sum(other_down) as other_down,
		sum(other_up) as other_up
	from
		users u,
		acs_rels r,
		(select distinct
			t.task_id,
			u.user_id,
			CASE WHEN u.user_id = t.trans_id and action_type_id=:down THEN 1 END as trans_down,
			CASE WHEN u.user_id = t.trans_id and action_type_id=:up THEN 1 END as trans_up,
			CASE WHEN u.user_id = t.edit_id and action_type_id=:down THEN 1 END as edit_down,
			CASE WHEN u.user_id = t.edit_id and action_type_id=:up THEN 1 END as edit_up,
			CASE WHEN u.user_id = t.proof_id and action_type_id=:down THEN 1 END as proof_down,
			CASE WHEN u.user_id = t.proof_id and action_type_id=:up THEN 1 END as proof_up,
			CASE WHEN u.user_id = t.other_id and action_type_id=:down THEN 1 END as other_down,
			CASE WHEN u.user_id = t.other_id and action_type_id=:up THEN 1 END as other_up
		from
			users u,
			acs_rels r,
			im_trans_tasks t,
			im_task_actions a
		where
			r.object_id_one = :project_id
			and r.object_id_one = t.project_id
			and u.user_id = r.object_id_two
			and (	u.user_id = t.trans_id 
				or u.user_id = t.edit_id 
				or u.user_id = t.proof_id 
				or u.user_id = t.other_id)
			and a.user_id = u.user_id
			and a.task_id = t.task_id
		) t
	where
		r.object_id_one = :project_id
		and r.object_id_two = u.user_id
		and u.user_id = t.user_id
	group by
		u.user_id
    "

    # ----- Get the absolute number of tasks by project phase ---------------

    set task_filecount_sql "
	select
		t.user_id,
		count(trans_ass) as trans_ass,
		count(edit_ass) as edit_ass,
		count(proof_ass) as proof_ass,
		count(other_ass) as other_ass,
		sum(trans_ass) as trans_words,
		sum(edit_ass) as edit_words,
		sum(proof_ass) as proof_words,
		sum(other_ass) as other_words
	from
		(select
			u.user_id,
			t.task_id,
			CASE WHEN u.user_id = t.trans_id THEN t.task_units END as trans_ass,
			CASE WHEN u.user_id = t.edit_id THEN t.task_units END as edit_ass,
			CASE WHEN u.user_id = t.proof_id THEN t.task_units END as proof_ass,
			CASE WHEN u.user_id = t.other_id THEN t.task_units END as other_ass
		from
			users u,
			acs_rels r,
			im_trans_tasks t
		where
			r.object_id_one = :project_id
			and r.object_id_one = t.project_id
			and u.user_id = r.object_id_two
			and (
				u.user_id = t.trans_id 
				or u.user_id = t.edit_id 
				or u.user_id = t.proof_id 
				or u.user_id = t.other_id
			)
		) t
	group by t.user_id
    "

    set task_sql "
	select
		u.user_id,
		im_name_from_user_id (u.user_id) as user_name,
		CASE WHEN c.trans_ass is null THEN 0 ELSE c.trans_ass END as trans_ass,
		CASE WHEN c.edit_ass is null THEN 0 ELSE c.edit_ass END as edit_ass,
		CASE WHEN c.proof_ass is null THEN 0 ELSE c.proof_ass END as proof_ass,
		CASE WHEN c.other_ass is null THEN 0 ELSE c.other_ass END as other_ass,
		CASE WHEN c.trans_words is null THEN 0 ELSE c.trans_words END as trans_words,
		CASE WHEN c.edit_words is null THEN 0 ELSE c.edit_words END as edit_words,
		CASE WHEN c.proof_words is null THEN 0 ELSE c.proof_words END as proof_words,
		CASE WHEN c.other_words is null THEN 0 ELSE c.other_words END as other_words,
		s.trans_down,
		s.trans_up,
		s.edit_down,
		s.edit_up,
		s.proof_down,
		s.proof_up,
		s.other_down,
		s.other_up
	from
		users u,
		acs_rels r,
		($task_status_sql) s,
		($task_filecount_sql) c
	where
		r.object_id_one = :project_id
		and r.object_id_two = u.user_id
		and u.user_id = s.user_id(+)
		and u.user_id = c.user_id(+)
    "

    # --------------------- Display the results ----------------------

    set ctr 1
    db_foreach task_status_sql $task_sql {

	# subtract the assigned files from the unassigned
	set unassigned_trans [expr $unassigned_trans - $trans_ass]
	set unassigned_edit [expr $unassigned_edit - $edit_ass]
	set unassigned_proof [expr $unassigned_proof - $proof_ass]
	set unassigned_other [expr $unassigned_other - $other_ass]

	set unassigned_trans_wc [expr $unassigned_trans_wc - $trans_words]
	set unassigned_edit_wc [expr $unassigned_edit_wc - $edit_words]
	set unassigned_proof_wc [expr $unassigned_proof_wc - $proof_words]
	set unassigned_other_wc [expr $unassigned_other_wc - $other_words]

	if {0 == $trans_ass} { set trans_ass "&nbsp;" }
	if {0 == $edit_ass} { set edit_ass "&nbsp;" }
	if {0 == $proof_ass} { set proof_ass "&nbsp;" }
	if {0 == $other_ass} { set other_ass "&nbsp;" }

	append task_status_html "
	<tr $bgcolor([expr $ctr % 2])>
	  <td>\n"

	if {$current_user_is_employee_p} {
	    append task_status_html "<A HREF=/intranet/users/view?user_id=$user_id>$user_name</A>\n"
	} else {
	    append task_status_html "User# $ctr\n"
	}

	append task_status_html "
	  </td>
	  <td>$trans_ass</td>
	  <td>$trans_down</td>
	  <td>$trans_up</td>
	
	  <td>$edit_ass</td>
	  <td>$edit_down</td>
	  <td>$edit_up</td>
	
	  <td>$proof_ass</td>
	  <td>$proof_down</td>
	  <td>$proof_up</td>
	
	  <td>$other_ass</td>
	  <td>$other_down</td>
	  <td>$other_up</td>
	
	  <td>$trans_words</td>
	  <td>$edit_words</td>
	  <td>$proof_words</td>
	</tr>
	"
	incr ctr
    }


    append xxx_task_status_html "
	<tr $bgcolor([expr $ctr % 2])>
	  <td>unassigned tasks</td>
	
	  <td>$unassigned_trans</td>
	  <td></td>
	  <td></td>
	
	  <td>$unassigned_edit</td>
	  <td></td>
	  <td></td>
	
	  <td>$unassigned_proof</td>
	  <td></td>
	  <td></td>
	
	  <td>$unassigned_other</td>
	  <td></td>
	  <td></td>
	
	  <td>[expr round($unassigned_trans_wc)]</td>
	  <td>[expr round($unassigned_edit_wc)]</td>
	  <td>[expr round($unassigned_proof_wc)]</td>
	
	</tr>
    "

    append task_status_html "
	<tr>
	  <td colspan=12 align=left>
    "

    if {[im_permission $current_user_id "view_trans_tasks"]} {
        append task_status_html "<input type=submit value='[_ intranet-translation.View_Tasks]' name=submit_view>\n"
        append task_status_html "<input type=submit value='[_ intranet-translation.Assign_Tasks]' name=submit_assign>\n"
    }

    append task_status_html "
	  </td>
	</tr>
    "

    append task_status_html "\n</table>\n</form>\n\n"


    # Update Project Advance Percentage
    im_trans_task_project_advance $project_id

    return $task_status_html
}



# -------------------------------------------------------------------
# Task Component
# Show the list of tasks for one project
# -------------------------------------------------------------------

ad_proc im_task_component { 
    {-include_subprojects_p 0}
    user_id 
    project_id 
    return_url 
    {view_name "trans_task_list"} 
} {
    Return a piece of HTML for the project view page,
    containing the list of tasks of a project.
} {
    set params [list [list include_subprojects_p $include_subprojects_p] [list user_id $user_id] [list project_id $project_id] [list return_url $return_url] [list view_name $view_name]]
    set result [ad_parse_template -params $params "/packages/intranet-translation/lib/trans-tasks"]
    return [string trim $result]
}


# -------------------------------------------------------------------
# Freelancer's version of the Task Component
# -------------------------------------------------------------------

ad_proc im_task_freelance_component { user_id project_id return_url } {
    Same as im_task_component, 
    except that this component is only shown to non-project
    administrators.
} {
    # Get the permissions for the current _project_
#    im_project_permissions $user_id $project_id project_view project_read project_write project_admin
#    if {$project_write} { return "" }

    # Only freelancers should see this component
    set freelance_p [im_profile::member_p -profile_id [im_freelance_group_id] -user_id $user_id]
    if {!$freelance_p} { return "" }

    return [im_task_component -include_subprojects_p 1 $user_id $project_id $return_url]
}



# -------------------------------------------------------------------
# Task Error Component
# -------------------------------------------------------------------

ad_proc im_task_error_component { user_id project_id return_url } {
    Return a piece of HTML for the project view page,
    containing the list of tasks that are not found in the filesystem.
} {
    # Is this a translation project?
    if {![im_project_has_type $project_id "Translation Project"]} {
	return ""
    }

    # Localize the workflow stage directories
    set locale "en_US"
    set source [lang::message::lookup $locale intranet-translation.Workflow_source_directory "source"]
    set trans [lang::message::lookup $locale intranet-translation.Workflow_trans_directory "trans"]
    set edit [lang::message::lookup $locale intranet-translation.Workflow_edit_directory "edit"]
    set proof [lang::message::lookup $locale intranet-translation.Workflow_proof_directory "proof"]
    set deliv [lang::message::lookup $locale intranet-translation.Workflow_deliv_directory "deliv"]
    set other [lang::message::lookup $locale intranet-translation.Workflow_other_directory "other"]


    # Show the missing tasks only to people who can write on the project
    im_project_permissions $user_id $project_id view read write admin
    if {!$write} { return "" }

    set err_count 0
    set task_table_rows ""
    
    # -------------------------------------------------------
    # Check that the path exists

    set project_path [im_filestorage_project_path $project_id]
    set source_language [db_string source_language "select im_category_from_id(source_language_id) from im_projects where project_id=:project_id" -default ""]
    if {![file isdirectory "$project_path/${source}_$source_language"]} {
	incr err_count
	append task_table_rows "<tr class=roweven><td colspan=99><font color=red>'$project_path/${source}_$source_language' does not exist</font></td></tr>\n"
    }

    # -------------------------------------------------------
    # Get the list of tasks with missing files

    if {!$err_count} {
	set missing_task_list [im_task_missing_file_list $project_id]
	ns_log Debug "im_task_error_component: missing_task_list=$missing_task_list"
    }


    # -------------------- SQL -----------------------------------
    set sql "
	select 
		min(t.task_id) as task_id,
		t.task_name,
		t.task_filename,
		t.task_units,
		im_category_from_id(t.source_language_id) as source_language,
		uom_c.category as uom_name,
		type_c.category as type_name
	from 
		im_trans_tasks t,
		im_categories uom_c,
		im_categories type_c
	where
		project_id=:project_id
		and t.task_status_id <> 372
		and t.task_uom_id=uom_c.category_id(+)
		and t.task_type_id=type_c.category_id(+)
	group by
		t.task_name,
		t.task_filename,
		t.task_units,
		t.source_language_id,
		uom_c.category,
		type_c.category
    "

    set bgcolor(0) " class=roweven"
    set bgcolor(1) " class=rowodd"
    set ctr 0

    db_foreach select_tasks $sql {

	if {$err_count} { continue }
	set upload_folder "${source}_$source_language"

	# only show the tasks that are in the "missing_task_list":
	if {[lsearch -exact $missing_task_list $task_id] < 0} {
	    continue
	}

	# Replace "/" characters in the Task Name (filename) by "/ ",
	# to allow the line to break more smoothely
	set task_name_list [split $task_name "/"]
	set task_name_splitted [join $task_name_list "/ "]

	append task_table_rows "
<tr $bgcolor([expr $ctr % 2])> 
  <td align=left><font color=red>$task_name_splitted</font></td>
  <td align=right>$task_units $uom_name</td>
  <td align=center>
    <A HREF='/intranet-translation/trans-tasks/upload-task?[export_url_vars project_id task_id return_url]'>
      [im_gif -translate_p 1 open "Upload file"]
    </A>
  </td>
</tr>\n"
	incr ctr
    }
    
    # Return an empty string if there are no errors
    if {$ctr == 0 && !$err_count} {
	return ""
	append task_table_rows "
<tr $bgcolor([expr $ctr % 2])>
  <td colspan=99 align=center>[_ intranet-translation.lt_No_missing_files_foun]</td>
</tr>
"
    }

    # ----------------- Put everything together -------------------------
    set task_table "
<form action=/intranet-translation/trans-tasks/task-action method=POST>
[export_form_vars project_id return_url]

<table border=0>
<tr>
  <td class=rowtitle align=center colspan=20>
    [_ intranet-translation.lt_Missing_Translation_F]
  </td>
</tr>
<tr> 
  <td class=rowtitle>[_ intranet-translation.Task_Name]</td>
  <td class=rowtitle>[_ intranet-translation.Units]</td>
  <td class=rowtitle>[im_gif -translate_p 1 open "Upload files"]</td>
</tr>

$task_table_rows

</table>
</form>\n"

    return $task_table
}


# -------------------------------------------------------------------
# New Tasks Component
# -------------------------------------------------------------------

ad_proc im_new_task_component { 
    user_id 
    project_id 
    return_url 
} {
    Return a piece of HTML to allow to add new tasks
} {
    if {![im_permission $user_id view_trans_proj_detail]} { return "" }
    im_project_permissions $user_id $project_id view read write admin
    if {!$write} { return "" }

    set params [list [list user_id $user_id] [list project_id $project_id] [list return_url $return_url]]
    set result [ad_parse_template -params $params "/packages/intranet-translation/lib/new-task"]
    return [string trim $result]
 
}


# ---------------------------------------------------------------------
# Determine the list of missing files
# ---------------------------------------------------------------------

ad_proc im_task_missing_file_list { 
    {-no_complain 0}
    project_id 
} {
    Returns a list of task_ids that have not been found
    in the project folder.
    These task_ids can be used to display a list of 
    files that the user has to upload to make the project
    workflow work without problems.
    The algorithm works O(n*log(n)), using ns_set, so
    it should be a reasonably cheap operation.

    @param no_complain Don't emit ad_return_complaint messages
           in order not to disturb a users's page with missing pathes etc.

} {
    set find_cmd [im_filestorage_find_cmd]


    # Localize the workflow stage directories
    set locale "en_US"
    set source [lang::message::lookup $locale intranet-translation.Workflow_source_directory "source"]
    set trans [lang::message::lookup $locale intranet-translation.Workflow_trans_directory "trans"]
    set edit [lang::message::lookup $locale intranet-translation.Workflow_edit_directory "edit"]
    set proof [lang::message::lookup $locale intranet-translation.Workflow_proof_directory "proof"]
    set deliv [lang::message::lookup $locale intranet-translation.Workflow_deliv_directory "deliv"]
    set other [lang::message::lookup $locale intranet-translation.Workflow_other_directory "other"]


    set query "
select
	p.project_nr as project_short_name,
	c.company_name as company_short_name,
	p.source_language_id,
	im_category_from_id(p.source_language_id) as source_language,
	p.project_type_id
from
	im_projects p,
	im_companies c
where
	p.project_id=:project_id
	and p.company_id=c.company_id(+)"

    if { ![db_0or1row projects_info_query $query] } {
	ad_return_complaint 1 "[_ intranet-translation.lt_Cant_find_the_project]"
	return
    }

    # No source language defined yet - we can only return an empty list here
    if {"" == $source_language} {
	return ""
    }

    set project_path [im_filestorage_project_path $project_id]
    set source_folder "$project_path/${source}_$source_language"
    set org_paths [split $source_folder "/"]
    set org_paths_len [llength $org_paths]

    ns_log Debug "im_task_missing_file_list: source_folder=$source_folder"
    ns_log Debug "im_task_missing_file_list: org_paths=$org_paths"
    ns_log Debug "im_task_missing_file_list: org_paths_len=$org_paths_len"
    
    if { [catch {
	set find_cmd [im_filestorage_find_cmd]
	set file_list [exec $find_cmd $source_folder -type f]
    } err_msg] } {
	# The directory probably doesn't exist yet, so don't generate
	# an error !!!

        if {$no_complain} { return "" }
	ad_return_complaint 1 "im_task_missing_file_list: directory $source_folder<br>
		       probably does not exist:<br>$err_msg"
	set file_list ""
    }

    # Get the sorted list of files in the directory
    set files [split $file_list "\n"]
    set file_set [ns_set create]

    foreach file $files {

	# Get the basic information about a file
	set file_paths [split $file "/"]
	set len [expr [llength $file_paths] - 1]
	set file_comps [lrange $file_paths $org_paths_len $len]
	set file_name [join $file_comps "/"]

	# Check if it is the toplevel directory
	if {[string equal $file $project_path]} { 
	    # Skip the path itself
	    continue 
	}

	ns_set put $file_set $file_name $file_name
	ns_log Debug "im_task_missing_file_list: file_name=$file_name"
    }

    # We've got now a list of all files in the source folder.
    # Let's go now through all the im_trans_tasks of this project and
    # check if the filename present in the $file_list
    # Attention!, this is an n^2 algorithm!
    # Any ideas how to speed this up?

    set task_sql "
select
	task_id,
	task_name,
	task_filename
from
	im_trans_tasks t
where
	t.project_id = :project_id
"

    set missing_file_list [list]
    db_foreach im_task_list $task_sql {

	if {"" != $task_filename} {
	    set res [ns_set get $file_set $task_filename]
	    if {"" == $res} {
		# We haven't found the file
		lappend missing_file_list $task_id
	    }
	}

    }

    ns_set free $file_set
    return $missing_file_list
}

ad_proc im_trans_trados_remove_sdlxliff {} {
    Remove the sdlxliff extension from the filename
    
} {
    db_foreach tasks {select task_name, task_id from im_trans_tasks where task_name like '%sdlxliff'} {
       set task_name [string trimright $task_name "sdlxliff"]
       set task_name [string range $task_name 0 end-1]
       catch {db_dml update "update im_trans_tasks set task_name = :task_name where task_id = :task_id"}
    }
    db_foreach tasks {select task_filename, task_id from im_trans_tasks where task_filename like '%sdlxliff'} {
       set task_filename [string trimright $task_filename "sdlxliff"]
       set task_filename [string range $task_filename 0 end-1]
       catch {db_dml update "update im_trans_tasks set task_filename = :task_filename where task_id = :task_id"}
    }
}

ad_proc im_trans_prices_populate_providers {
    {-company_id ""}
} {
    Populate Trans prices from previous invoices or bills
} {
    # Get the distinct list of prices
    
    # task_type_id - im_trans_tasks
    # Target Language ID - im_trans_tasks
    # source_langauge_id
    # subject_area_id
    # price
    # currency
    
    
    # Check for each of the assignments        
    foreach type [list trans edit proof] {
        
        # We try to find the correct trans type id. If we have prices maintained though for Trans as well as Trans / Edit, we will most likely not get the proper result, especially not if we have two different Project Types which have 
        # Trans on it's own but are referrenced for the same company.
        set task_type_id [db_string task "select category_id from im_categories where aux_string1 = :type and category_type = 'Intranet Project Type' limit 1" -default ""]
        
        
  
        db_foreach tasks "select distinct c.provider_id, tt.target_language_id, tt.source_language_id, p.subject_area_id, tt.task_units, ii.item_uom_id, ii.item_units, ii.price_per_unit, ii.currency from im_trans_tasks tt, im_invoice_items ii,im_costs c, im_projects p,im_companies co where p.project_id = tt.project_id and ii.task_id = tt.task_id and c.cost_id = ii.invoice_id and c.cost_type_id = 3704 and ii.price_per_unit not in (select price from im_trans_prices where uom_id = ii.item_uom_id and company_id = c.provider_id and task_type_id = tt.task_type_id and target_language_id = tt.target_language_id and source_language_id = tt.source_language_id and subject_area_id = p.subject_area_id and currency = ii.currency) and tt.${type}_id = co.primary_contact_id and co.company_id = c.provider_id and item_uom_id in (320,324)
            order by provider_id" {
            if {$price_per_unit eq ""} {continue}
            if {$item_units == "1.0" && $task_units == "1.0"} {continue}
            if {$item_units == "1.0" && $task_units > 1} {
                set price_per_unit [expr $price_per_unit / $task_units]
            }
            
            set existing_price_per_unit [db_string test "select max(price) from im_trans_prices where uom_id = :item_uom_id and company_id = :provider_id and task_type_id = :task_type_id and target_language_id = :target_language_id and source_language_id = :source_language_id and subject_area_id = :subject_area_id and currency = :currency" -default ""]
            if {$existing_price_per_unit >= $price_per_unit} {
                ds_comment "Skipping $provider_id :: $price_per_unit"
                continue
            }
            if {$price_per_unit > 0.3 && $item_uom_id == 324} {
                ds_comment "Too high price $price_per_unit :: $provider_id"
                continue
            }
            db_dml delete_prices "delete from im_trans_prices where uom_id = :item_uom_id and company_id = :provider_id and task_type_id = :task_type_id and target_language_id = :target_language_id and source_language_id = :source_language_id and subject_area_id = :subject_area_id and currency = :currency"
            set price_per_unit [format "%.3f" $price_per_unit]
                db_dml price_insert "
                insert into im_trans_prices (
                    price_id,
                    uom_id,
                    company_id,
                    task_type_id,
                    target_language_id,
                    source_language_id,
                    subject_area_id,
                    currency,
                    price
                ) values (
                    nextval('im_trans_prices_seq'),
                    :item_uom_id,
                    :provider_id,
                    :task_type_id,
                    :target_language_id,
                    :source_language_id,
                    :subject_area_id,
                    :currency,
                    :price_per_unit
                )"
            ds_comment "$provider_id :: $task_type_id :: $target_language_id :: $source_language_id :: $subject_area_id :: $currency$price_per_unit"        
        } 
    }
    
    # Transfer the prices from timesheet prices
    # http://kolibri.sussdorff.org/intranet/companies/view?company_id=273588
    db_foreach timesheet_prices {
        select uom_id,company_id,task_type_id,currency,price from im_timesheet_prices
    } {
        switch $task_type_id {
            88 - 10000011 - 10000014 {
                set task_type_id 88
            }
            89 - 93 {
                set task_type_id 93
            }
            default {
                set task_type_id ""
            }
        }
        
        if {$task_type_id eq ""} {continue} 
        set existing_price_per_unit [db_string test "select max(price) from im_trans_prices where uom_id = :uom_id and company_id = :company_id and task_type_id = :task_type_id and target_language_id is null and source_language_id is null and subject_area_id is null and currency = :currency" -default ""]
        
        if {$existing_price_per_unit >= $price} {
            ds_comment "Skipping $provider_id :: $price_per_unit"
            continue
        }
        if {$price > 0.3 && $uom_id == 324} {
            ds_comment "Too high price $price :: $provider_id"
            continue
        }
        
        db_dml price_insert "
        insert into im_trans_prices (
            price_id,
            uom_id,
            company_id,
            task_type_id,
            target_language_id,
            source_language_id,
            subject_area_id,
            currency,
            price
        ) values (
            nextval('im_trans_prices_seq'),
            :uom_id,
            :company_id,
            :task_type_id,
            NULL,
            NULL,
            NULL,
            :currency,
            :price
        )"
        ds_comment "inserting trans price $price :: $company_id :: $uom_id"
    }
    
    # update the price types
    db_dml update "update im_trans_prices set task_type_id = 93 where task_type_id in (87,89,94,2500)"
}