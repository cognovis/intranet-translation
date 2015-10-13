# /packages/intranet-translation/projects/new.tcl
#
# Copyright (c) 2011, cognovís GmbH, Hamburg, Germany
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see
# <http://www.gnu.org/licenses/>.
#
 
ad_page_contract {
    
    Purpose: form to quickly add a translation project
    @author Malte Sussdorff (malte.sussdorff@cognovis.de)
    @creation-date 2011-08-05
} {
    {project_type_id ""}
    {project_status_id:integer,optional}
    {company_id:integer}
    {parent_id ""}
    {project_nr ""}
    {project_name ""}
    {workflow_key ""}
    {return_url ""}
    target_language_ids:multiple,optional
}

# -----------------------------------------------------------
# Defaults
# -----------------------------------------------------------
set user_id [ad_maybe_redirect_for_registration]

    
set perm_p 0
# Check if the user has admin rights on the parent_id
# to allow freelancers to add sub-projects
if {"" != $parent_id} {
    im_project_permissions $user_id $parent_id view read write admin
    if {$admin} { set perm_p 1 }
}
    
# Users with "add_projects" privilege can always create new projects...
if {[im_permission $user_id add_projects]} { set perm_p 1 } 
if {!$perm_p} { 
    ad_return_complaint "Insufficient Privileges" "
        <li>You don't have sufficient privileges to see this page."
    return
}
    
# --------------------------------------------
# Create Form
# --------------------------------------------

set form_id "project-ae"
set target_language_options [db_list_of_lists languages "select category,category_id from im_categories where category_type = 'Intranet Translation Language' and enabled_p = 't' order by category"]
set options_list [list [list "Unzip File?"  "t"]]

ad_form -name $form_id -html { enctype multipart/form-data } -action /intranet-translation/projects/new-quick -cancel_url $return_url -form {
    project_id:key
    {company_id:integer(hidden) {value $company_id}}
    {source_language_id:text(select)
        {label "[_ intranet-translation.Source_Language]"}
        {options "$target_language_options"}
    }
    {target_language_ids:text(multiselect)
        {label "[_ intranet-translation.Target_Languages]"}
        {options "$target_language_options"}
    }
    {subject_area_id:integer(im_category_tree)
        {label "Subject Area"}
        {custom {category_type "Intranet Translation Subject Area" translate_p 1}}
    }
    {final_company:text(text),optional
        {label "Final Company"}
    }
    {upload_file:file(file),optional
        {label "#acs-subsite.Filename#"}
        {help_text "[_ acs-subsite.lt_Use_the_Browse_button]"}
    }
    {zip_p:text(checkbox),optional
        {label ""}
        {options $options_list}
    }

} -on_submit {

    if { ![exists_and_not_null zip_p] } {
        set zip_p "f"
    }    

    # Permission check. Cases include a user with full add_projects rights,
    # but also a freelancer updating an existing project or a freelancer
    # creating a sub-project of a project he or she can admin.
    set perm_p 0
    
    # Check for the case that this guy is a freelance
    # project manager of the project or similar...
    im_project_permissions $user_id $project_id view read write admin
    if {$write} { set perm_p 1 }
    
    # Check if the user has admin rights on the parent_id
    # to allow freelancers to add sub-projects
    if {"" != $parent_id} {
        im_project_permissions $user_id $parent_id view read write admin
        if {$write} { set perm_p 1 }
    }

    # Users with "add_projects" privilege can always create new projects...
    if {[im_permission $user_id add_projects]} { set perm_p 1 } 

    if {!$perm_p} { 
        ad_return_complaint "Insufficient Privileges" "<li>You don't have sufficient privileges to see this page."
        ad_script_abort
    }
    
} -new_data {

    set target_language_ids [element get_values $form_id target_language_ids]

    set project_id [im_translation_create_project \
        -company_id $company_id \
        -project_lead_id [ad_conn user_id] \
        -source_language_id $source_language_id \
        -target_language_ids $target_language_ids \
        -subject_area_id $subject_area_id \
        -final_company $final_company]  
        
    # Now analyse the trados file
    
    if {[exists_and_not_null upload_file]} {
        # Read the file
        set wordcount_file [template::util::file::get_property tmp_filename $upload_file]
        
        # ---------------------------------------------------------------------
        # Get the file and deal with Unicode encoding...
        # ---------------------------------------------------------------------
        
        if {[catch {
            set fl [open $wordcount_file]
            fconfigure $fl -encoding binary
            set binary_content [read $fl]
            close $fl
        } err]} {
            ad_return_complaint 1 "Unable to open file $wordcount_file:<br><pre>\n$err</pre>"
            return
        }
        
        set encoding_bin [string range $binary_content 0 1]
        binary scan $encoding_bin H* encoding_hex
        ns_log Notice "trados-import: encoding_hex=$encoding_hex"
        
        switch $encoding_hex {
            fffe {
                # Assume a UTF-16 file
                set encoding "unicode"
            }
            default {
                # Assume a UTF-8 file
                set encoding "utf-8"
            }
        }
    
        if {[catch {
            set fl [open $wordcount_file]
            fconfigure $fl -encoding $encoding 
            set trados_files_content [read $fl]
            close $fl
        } err]} {
            ad_return_complaint 1 "Unable to open file $wordcount_file:<br><pre>\n$err</pre>"
            return
        }

        # Analyse it
        im_trans_trados_create_tasks \
            -project_id $project_id \
            -trados_analysis_xml $trados_files_content
            
        # Create the quote
        im_trans_invoice_create_from_tasks -project_id $project_id
    }
      
     
} -after_submit {
    
    # -----------------------------------------------------------------
    # Flush caches related to the project's information
    
    util_memoize_flush_regexp "im_project_has_type_helper.*"
    util_memoize_flush_regexp "db_list_of_lists company_info.*"
    
    # -----------------------------------------------------------------
    # Call the "project_create" or "project_update" user_exit
    
    im_user_exit_call project_create $project_id
        
    set return_url [export_vars -base "/intranet/projects/view" {project_id}]
        
    ad_returnredirect $return_url
    ad_script_abort
}