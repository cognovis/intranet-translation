# /packages/intranet-translation/tcl/intranet-trans-trados-procs.tcl


ad_library {
    Bring together all "components" (=HTML + SQL code)
    related to the Translation sector for TRADOS

	@author malte.sussdorff@cognovis.de
    @author frank.bergmann@project-open.com
    @author juanjoruizx@yahoo.es
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
        	set company_id [db_string project_company "select company_id from im_projects where project_id=:project_id"]
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


ad_proc -public im_trans_trados_create_tasks {
	{-project_id:required}
	{-tm_folder "trados"}
	{-trados_analysis_xml ""}
} {
	Create translation tasks from trados analysis
} {

	# ---------------------------------------------------------------------
	# Get some more information about the project
	# ---------------------------------------------------------------------
	
	set project_query "
		select
			p.project_nr as project_short_name,
			p.company_id,
			c.company_name as company_short_name,
			p.source_language_id,
			p.project_type_id,
			p.project_lead_id
		from
			im_projects p
			  LEFT JOIN
			im_companies c USING (company_id)
		where
			p.project_id=:project_id
	"
	if { ![db_0or1row projects_info_query $project_query] } {
		ad_return_complaint 1 "[_ intranet-translation.lt_Cant_find_the_project]"
		return
	}

	# ---------------------------------------------------------------------
	# Define some constants
	# ---------------------------------------------------------------------
	
	set attr_segments "segments"
	set attr_words "words"
	set attr_characters "characters"
	set attr_placeables "placeables"
	set attr_characters "characters"
	set attr_min "min"
	set attr_max "max"
	set attr_name "name"
	
	# Parse the Trados 9.0 XML
	#
	if {[catch {set doc [dom parse $trados_analysis_xml]} err_msg]} {
	
		ad_return_complaint 1 "Error parsing Trados XML:<br><pre>$err_msg</pre>"
		ad_script_abort
	}
	
	# TRADOS version 9.0 XML test logic 
	set root_element [$doc documentElement]
	set nodeName [$root_element nodeName] 
	
	# Make sure the root element is "task"
	#
	if { [string tolower $nodeName] == "task" } {
	
		set trados_version "9.0"
		set list_files [$root_element getElementsByTagName "file"]       
		set trados_files_len [llength $list_files]
	
	} else {
	
		ad_return_complaint 1 "Unable to detect the version of the Trados file:<br>
		Please, check if the uploaded file is a valid Trados XML analysis."
		ad_script_abort
	
	}  
	
	# Loop through all "task" elements in the Trados XML structure
	set ctr 0
	set created_task_ids [list]
	for {set i 0} {$i < $trados_files_len} {incr i} {
	
		set px_segments 0
		set px_words 0 
		set px_placeables 0  
	
		set p100_segments 0
		set p100_words 0 
		set p100_placeables 0		    
	
		set prep_segments 0
		set prep_words 0 
		set prep_placeables 0
	
		set p0_segments 0
		set p0_words 0 
		set p0_placeables 0
	
		set pperfect_segments 0
		set pperfect_words 0 
		set pperfect_placeables 0
	
		set locked_segments 0
		set locked_words 0
		set locked_placeables 0
	
		set pcrossfilerepeated_segments 0
		set pcrossfilerepeated_words 0 
		set pcrossfilerepeated_placeables 0
	
		set f95_segments 0
		set f95_words 0 
		set f95_placeables 0
	
		set f85_segments 0
		set f85_words 0 
		set f85_placeables 0			  
	
		set f75_segments 0
		set f75_words 0 
		set f75_placeables 0			  
	
		set f50_segments 0
		set f50_words 0 
		set f50_placeables 0			  
	
		set locked_segments 0
		set locked_words 0 
		set locked_placeables 0			  
	
		set p95_segments 0
		set p95_words 0 
		set p95_placeables 0
	
		set p85_segments 0
		set p85_words 0 
		set p85_placeables 0			  
	
		set p75_segments 0
		set p75_words 0 
		set p75_placeables 0			  
	
		set p50_segments 0
		set p50_words 0 
		set p50_placeables 0			  
	
	
	
		if {[string equal $trados_version "9.0"]} {
		set childnode [lindex $list_files $i]
		set filename [$childnode getAttribute $attr_name]
	
		# Remove the sdlxliff
		set filename [string trimright $filename "sdlxliff"]
		set filename [string range $filename 0 end-1]
	
		ns_log Notice "trados-import: Xml import of the $filename file."
		set analyseElement [$childnode firstChild] 
	
		foreach analyseChildElement [$analyseElement childNodes] {
			set elementName [string tolower [$analyseChildElement nodeName]]
	
			#going through the attributes of the "analyse" element
			switch $elementName {
			"incontextexact" {
				set px_segments [$analyseChildElement getAttribute $attr_segments]
				set px_words [$analyseChildElement getAttribute $attr_words] 
				set px_placeables [$analyseChildElement getAttribute $attr_placeables]  
			}
			"exact" {
				set p100_segments [$analyseChildElement getAttribute $attr_segments]
				set p100_words [$analyseChildElement getAttribute $attr_words] 
				set p100_placeables [$analyseChildElement getAttribute $attr_placeables]		    
			}
			"locked" {
				set locked_segments [$analyseChildElement getAttribute $attr_segments]
				set locked_words [$analyseChildElement getAttribute $attr_words] 
				set locked_placeables [$analyseChildElement getAttribute $attr_placeables]
			}
			"repeated" {
				set prep_segments [$analyseChildElement getAttribute $attr_segments]
				set prep_words [$analyseChildElement getAttribute $attr_words] 
				set prep_placeables [$analyseChildElement getAttribute $attr_placeables]
			}
			"new" {
				set p0_segments [$analyseChildElement getAttribute $attr_segments]
				set p0_words [$analyseChildElement getAttribute $attr_words] 
				set p0_placeables [$analyseChildElement getAttribute $attr_placeables]
			}
			"perfect" {
				# new
				set pperfect_segments [$analyseChildElement getAttribute $attr_segments]
				set pperfect_words [$analyseChildElement getAttribute $attr_words] 
				set pperfect_placeables [$analyseChildElement getAttribute $attr_placeables]
			}
			"crossfilerepeated" {
				# new
				set pcrossfilerepeated_segments [$analyseChildElement getAttribute $attr_segments]
				set pcrossfilerepeated_words [$analyseChildElement getAttribute $attr_words] 
				set pcrossfilerepeated_placeables [$analyseChildElement getAttribute $attr_placeables]
			}
			"total" {
				# ignore
			}
			"internalfuzzy" {
				#going through all "fuzzy" elements
				set fuzzy_min_attribute [$analyseChildElement getAttribute $attr_min]
				switch $fuzzy_min_attribute {
				"95" {
					set f95_segments [$analyseChildElement getAttribute $attr_segments]
					set f95_words [$analyseChildElement getAttribute $attr_words] 
					set f95_placeables [$analyseChildElement getAttribute $attr_placeables]
				}
				"85" {
					set f85_segments [$analyseChildElement getAttribute $attr_segments]
					set f85_words [$analyseChildElement getAttribute $attr_words] 
					set f85_placeables [$analyseChildElement getAttribute $attr_placeables]			  
				}
				"75" {
					set f75_segments [$analyseChildElement getAttribute $attr_segments]
					set f75_words [$analyseChildElement getAttribute $attr_words] 
					set f75_placeables [$analyseChildElement getAttribute $attr_placeables]			  
				}
				"50" {
					set f50_segments [$analyseChildElement getAttribute $attr_segments]
					set f50_words [$analyseChildElement getAttribute $attr_words] 
					set f50_placeables [$analyseChildElement getAttribute $attr_placeables]			  
				}
				default {
					ad_return_complaint 1 "trados-xml-import: Found unknown fuzzy min attribute '$fuzzy_min_attribute'"
				}
				}
			}
			"fuzzy" {
				#going through all "fuzzy" elements
				set fuzzy_min_attribute [$analyseChildElement getAttribute $attr_min]
				switch $fuzzy_min_attribute {
				"95" {
					set p95_segments [$analyseChildElement getAttribute $attr_segments]
					set p95_words [$analyseChildElement getAttribute $attr_words] 
					set p95_placeables [$analyseChildElement getAttribute $attr_placeables]
				}
				"85" {
					set p85_segments [$analyseChildElement getAttribute $attr_segments]
					set p85_words [$analyseChildElement getAttribute $attr_words] 
					set p85_placeables [$analyseChildElement getAttribute $attr_placeables]			  
				}
				"75" {
					set p75_segments [$analyseChildElement getAttribute $attr_segments]
					set p75_words [$analyseChildElement getAttribute $attr_words] 
					set p75_placeables [$analyseChildElement getAttribute $attr_placeables]			  
				}
				"50" {
					set p50_segments [$analyseChildElement getAttribute $attr_segments]
					set p50_words [$analyseChildElement getAttribute $attr_words] 
					set p50_placeables [$analyseChildElement getAttribute $attr_placeables]			  
				}
				default {
					ad_return_complaint 1 "trados-xml-import: Found unknown fuzzy min attribute '$fuzzy_min_attribute'"
				}
				}
			}
			default {
				ad_return_complaint 1 "trados-xml-import: Found unknown element '$elementName'"
			}
			}  
		}  
		} 
	
	
		set task_name $filename
	
		# Calculate the number of "effective" words based on
		# a valuation of repetitions
	
		# Determine the "effective" wordcount of the task:
		# Get the "task_units" from a special company called "default_freelance"
		#
		set task_units [im_trans_trados_matrix_calculate [im_company_freelance] $px_words $prep_words $p100_words $p95_words $p85_words $p75_words $p50_words $p0_words \
				   $pperfect_words $pcrossfilerepeated_words $f95_words $f85_words $f75_words $f50_words $locked_words]
	
		# Determine the "billable_units" form the project's customer:
		#
	
		set billable_units [im_trans_trados_matrix_calculate $company_id $px_words $prep_words $p100_words $p95_words $p85_words $p75_words $p50_words $p0_words \
				   $pperfect_words $pcrossfilerepeated_words $f95_words $f85_words $f75_words $f50_words $locked_words]
	
		# Inter-Company invoicing enabled?
		set interco_p [parameter::get_from_package_key -package_key "intranet-translation" \
		 	-parameter "EnableInterCompanyInvoicingP" -default 0]
		set billable_units_interco $billable_units
		if {$interco_p} {
			set interco_company_id [db_string get_interco_company "select interco_company_id from im_projects where project_id=$project_id" -default ""]
			if {"" == $interco_company_id} { 
				set interco_company_id $company_id 
			}
			set billable_units_interco [im_trans_trados_matrix_calculate $interco_company_id $px_words $prep_words $p100_words $p95_words $p85_words $p75_words $p50_words $p0_words \
						$pperfect_words $pcrossfilerepeated_words $f95_words $f85_words $f75_words $f50_words $locked_words]
		}
	
		set task_status_id 340
		set task_description ""
		# source_language_id defined by im_project
		# 324=Source words
		set task_uom_id 324	
		set invoice_id ""
	
		# Add a new task for every project target language
		set insert_sql ""
		
		# Check for accents and other non-ascii characters
		set charset [ad_parameter -package_id [im_package_filestorage_id] FilenameCharactersSupported "" "alphanum"]

		foreach target_language_id [im_target_language_ids $project_id] {
		
				set task_name_comps [split $task_name "/"]
				set task_name_len [expr [llength $task_name_comps] - 1]
				set task_name_body [lindex $task_name_comps $task_name_len]
				set filename $task_name_body
		
				if {![im_filestorage_check_filename $charset $filename]} {
				return -code 10 [lang::message::lookup "" intranet-filestorage.Invalid_Character_Set "
					<b>Invalid Character(s) found</b>:<br>
					Your filename '%filename%' contains atleast one character that is not allowed
					in your character set '%charset%'."]
				}
		
				db_transaction {
					set new_task_id [im_exec_dml new_task "im_trans_task__new (
						null,			-- task_id
						'im_trans_task',	-- object_type
						now(),			-- creation_date
						:project_lead_id,		-- creation_user
						'0.0.0.0.',		-- creation_ip	
						null,			-- context_id	
						:project_id,		-- project_id	
						:project_type_id,		-- task_type_id	
						:task_status_id,	-- task_status_id
						:source_language_id,	-- source_language_id
						:target_language_id,	-- target_language_id
						:task_uom_id		-- task_uom_id
						)"]
			
					db_dml update_task "
						UPDATE im_trans_tasks SET
						tm_integration_type_id = [im_trans_tm_integration_type_external],
						task_name = :task_name,
						task_filename = :task_name,
						description = :task_description,
						task_units = :task_units,
						billable_units = :billable_units,
						billable_units_interco = :billable_units_interco,
						match_x = :px_words,
						match_rep = :prep_words,
						match100 = :p100_words, 
						match95 = :p95_words,
						match85 = :p85_words,
						match75 = :p75_words, 
						match50 = :p50_words,
						match0 = :p0_words,
						match_perf = :pperfect_words,
						match_cfr = :pcrossfilerepeated_words,
						match_f95 = :f95_words,
						match_f85 = :f85_words,
						match_f75 = :f75_words,
						match_f50 = :f50_words,
						locked = :locked_words
						WHERE 
						task_id = :new_task_id
						"
				}

		
				# Successfully created translation task
				# Call user_exit to let TM know about the event
				im_user_exit_call trans_task_create $new_task_id
				im_audit -object_type "im_trans_task" -action after_create -object_id $new_task_id -status_id $task_status_id -type_id $project_type_id
				lappend created_task_ids $new_task_id
			
	
		} 
		# end of foreach
	}
	#end of the for loop
}