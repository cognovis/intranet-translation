
    
        set default_uom [parameter::get_from_package_key -package_key intranet-trans-invoices -parameter "DefaultPriceListUomID" -default 324]
    
        # More then one option for a TM?
        # Then we'll have to show a few more fields later.
        set ophelia_installed_p [llength [info procs im_package_ophelia_id]]
    
        # Localize the workflow stage directories
        set locale "en_US"
        set source [lang::message::lookup $locale intranet-translation.Workflow_source_directory "source"]
        set trans [lang::message::lookup $locale intranet-translation.Workflow_trans_directory "trans"]
        set edit [lang::message::lookup $locale intranet-translation.Workflow_edit_directory "edit"]
        set proof [lang::message::lookup $locale intranet-translation.Workflow_proof_directory "proof"]
        set deliv [lang::message::lookup $locale intranet-translation.Workflow_deliv_directory "deliv"]
        set other [lang::message::lookup $locale intranet-translation.Workflow_other_directory "other"]
    
    
        set bgcolor(0) " class=roweven"
        set bgcolor(1) " class=rowodd"
    
        # --------- Get a list of files "source_xx_XX" dir---------------
        # $file_list is a sorted list of all files in "source_xx_XX":
        set task_list [list]
    
        # Get some basic information about our current project
        db_1row project_info "
        select	project_type_id
        from	im_projects
        where	project_id = :project_id
        "
    
    
        # Get the sorted list of files in the directory
        set files [lsort [im_filestorage_find_files $project_id]]
    
        set project_path [im_filestorage_project_path $project_id]
        set org_paths [split $project_path "/"]
        set org_paths_len [llength $org_paths]
        set start_index $org_paths_len
    
        foreach file $files {
    
        # Get the basic information about a file
        ns_log Debug "file=$file"
        set file_paths [split $file "/"]
        set file_paths_len [llength $file_paths]
        set body_index [expr $file_paths_len - 1]
        set file_body [lindex $file_paths $body_index]
    
        # The first folder of the project - contains access perms
        set top_folder [lindex $file_paths $start_index]
        ns_log Debug "top_folder=$top_folder"
    
        # Check if it is the toplevel directory
        if {[string equal $file $project_path]} { 
            # Skip the path itself
            continue 
        }
    
        # determine the part of the filename _after_ the base path
        set end_path ""
        for {set i [expr $start_index+1]} {$i < $file_paths_len} {incr i} {
            append end_path [lindex $file_paths $i]
            if {$i < [expr $file_paths_len - 1]} { append end_path "/" }
        }
    
        # add "source_xx_XX" folder contents to file_list
        if {[regexp ${source} $top_folder]} {
            # append twice: for right and left side of select box
            lappend task_list $end_path
            lappend task_list $end_path
        }
        }
    
        set ctr 0
    
        # -------------------- Add subheader for New Task  --------------------------
        set task_table "
            <form enctype=multipart/form-data method=POST action=/intranet-translation/trans-tasks/trados-upload>
            [export_form_vars project_id return_url]
    <table border=0>
    <tr>
      <td colspan=1 class=rowtitle align=center>
        [lang::message::lookup "" intranet-translation.Add_Tasks_From_TM_Analysis "Add New Tasks From a Translation Memory Analysis"]
      </td>
      <td class=rowtitle align=center>
        [_ intranet-translation.Help]
      </td>
    </tr>
    "
    
        # -------------------- Add an Asp Wordcount -----------------------
    
        set target_language_option_list [db_list target_lang_options "
        select	'<option value=\"' || language_id || '\">' || 
            im_category_from_id(language_id) || '</option>'
        from	im_target_languages
        where	project_id = :project_id
        "]
        set target_language_options [join $target_language_option_list "\n"]
    
        if {[ad_parameter -package_id [im_package_translation_id] EnableAspTradosImport "" 0]} {
    
        # Prepare the list of importers. 
        # Start with the hard-coded importers coming with ]po[
        set importer_option_list [list \
                      [list trados "Trados (3.0 - 9.0)"] \
                      [list transit "Transit (all)"] \
                      [list freebudget "FreeBudget (4.0 - 5.0)"] \
                      [list webbudget "WebBudget (4.0 - 5.0"] \
                     ]
        set importer_sql "
            select	category
            from	im_categories
            where	category_type = 'Intranet Translation Task CSV Importer'
                and (enabled_p is null OR enabled_p = 't')
        "
        set default_wordcount_app [ad_parameter -package_id [im_package_translation_id] "DefaultWordCountingApplication" "" "trados"]
        db_foreach importers $importer_sql {
            lappend importer_option_list [list $category [lang::message::lookup "" intranet-translation.Importer_$category $category]]
        }
    
        set importer_options_html ""
        foreach row $importer_option_list {
            set importer [lindex $row 0]
            set importer_pretty [lindex $row 1]
            set selected ""
             if {$importer == $default_wordcount_app} { set selected "selected" }
            append importer_options_html "<option value=\"[lindex $row 0]\" $selected>$importer_pretty</option>\n"
        }
    
        append task_table "
        <tr $bgcolor(0)> 
          <td>
            <nobr>
            <input type=file name=upload_file size=30 value='*.csv'>
            <select name=wordcount_application>
            $importer_options_html
            </select>
            "
        append task_table "<input type=hidden name='tm_integration_type_id' value='[im_trans_tm_integration_type_external]'>\n"
        append task_table [im_trans_task_type_select task_type_id $project_type_id]
    
        append task_table "
        <select name=target_language_id>
        <option value=\"\">[lang::message::lookup "" intranet-translation.All_languages "All Languages"]</option>
        $target_language_options
        </select>
        <input type=submit value='[lang::message::lookup "" intranet-translation.Add_Wordcount "Add Wordcount"]' name=submit_trados>
        </form>
        </nobr>
      </td>
      <td>
        [im_gif -translate_p 1 help "Use the 'Browse...' button to locate your file, then click 'Open'.\nThis file is used to define the tasks of the project, one task for each line of the wordcount file."]
      </td>
    </tr>
    "
        }
    
    
        # -------------------- Ophelia or Not -----------------------
        set ext [im_trans_tm_integration_type_external]
        if {$ophelia_installed_p} {
        set integration_type_html [im_category_select "Intranet TM Integration Type" tm_integration_type_id $ext]
        set integration_type_html "<td>$integration_type_html</td>"
        set colspan 8
        } else {
        set integration_type_html "<input type=hidden name=tm_integration_type_id value=$ext>"
        set colspan 7
        }
    
    
        # -------------------- Add an Intermediate Header -----------------------
        append task_table "
        </table>
        </form>
    
        <form action=/intranet-translation/trans-tasks/task-action method=POST>
        [export_form_vars project_id return_url]
    
        <table border=0>
        <tr><td colspan=$colspan></td></br>
    
        <tr>
        <td colspan=$colspan class=rowtitle align=center>
        [lang::message::lookup "" intranet-translation.Add_Individual_Files "Add Individual Files"]
        </td>
        </tr>
        <tr>
          <td class=rowtitle align=center>
            [_ intranet-translation.Task_Name]
          </td>
          <td class=rowtitle align=center>
            [_ intranet-translation.Units]
          </td>
          <td class=rowtitle align=center>
            [_ intranet-translation.UoM]
          </td>
          <td class=rowtitle align=center>
            [_ intranet-translation.Task_Type]
          </td>
          <td class=rowtitle align=center>
            [lang::message::lookup "" intranet-translation.Target_Language "Target Language"]
          </td>
        "
    
        if {$ophelia_installed_p} {
        append task_table "
          <td class=rowtitle align=center>
           [lang::message::lookup "" intranet-translation.Integration_Type "Integration"]
          </td>
        "
        }
        append task_table "
            <td class=rowtitle align=center>
            [_ intranet-translation.Task_Action]
            </td>
            <td class=rowtitle align=center>&nbsp;</td>
        </tr>
         "
    
        # -------------------- Add a new File  --------------------------
    
        if {0 < [llength $task_list]} {
        append task_table "
      <tr $bgcolor(0)> 
    
        <td>[im_select -translate_p 0 "task_name_file" $task_list]</td>
        <td><input type=text size=2 value=0 name=task_units_file></td>
        <td>[im_category_select "Intranet UoM" "task_uom_file" $default_uom]</td>
        <td>[im_trans_task_type_select task_type_file $project_type_id]</td>
            <td>
                <select name=target_language_id>
                <option value=\"\">[lang::message::lookup "" intranet-translation.All_languages "All Languages"]</option>
                $target_language_options
                </select>
            </td>
        $integration_type_html
        <td><input type=submit value=\"[_ intranet-translation.Add_File]\" name=submit_add_file></td>
        <td>[im_gif -translate_p 1 help "Add a new file to the list of tasks. \n New files need to be located in the \"source_xx\" folder to appear in the drop-down box on the left."]</td>
      </tr>
    "
        }
    
        # -------------------- Add Task Manually --------------------------
        append task_table "
    
      <tr $bgcolor(0)> 
    
        <td><input type=text size=20 value=\"\" name=task_name_manual></td>
        <td><input type=text size=2 value=0 name=task_units_manual></td>
        <td>[im_category_select "Intranet UoM" "task_uom_manual" $default_uom]</td>
        <td>[im_trans_task_type_select task_type_manual $project_type_id]</td>
            <td>
                <select name=target_language_id>
                <option value=\"\">[lang::message::lookup "" intranet-translation.All_languages "All Languages"]</option>
                $target_language_options
                </select>
            </td>
        $integration_type_html
        <td><input type=submit value=\"[_ intranet-translation.Add]\" name=submit_add_manual></td>
        <td>[im_gif -translate_p 1 help "Add a \"manual\" task to the project. \n This task is not going to controled by the translation workflow."]</td>
      </tr>"
    
        append task_table "
    </table>
    </form>
    "