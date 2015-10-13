# /packages/intranet-translation/tcl/intranet-translation-callback-procs.tcl
# Please check http://www.project-open.com/ for licensing
# details.

ad_library {
    Specific stuff for translation callbacks

    @author malte.sussdorff@cognovis.de
    
}

ad_proc -public -callback im_project_new_redirect -impl translation {
    {-object_id:required}
    {-status_id ""}
    {-type_id ""}
    {-project_id:required}
    {-parent_id:required}
    {-company_id:required}
    {-project_type_id:required}
    {-project_name:required}
    {-project_nr:required}
    {-workflow_key:required}
    {-return_url:required}
} {
    Redurect if needed
} {
    # Returnredirect to translations for translation projects
    if {[im_category_is_a $project_type_id [im_project_type_translation]] && $project_id eq ""} {
        if {[parameter::get_from_package_key -package_key "intranet-translation" -parameter "QuickProjectCreationP"]} {
            ad_returnredirect [export_vars -base "/intranet-translation/projects/new-quick" -url {project_type_id project_status_id company_id parent_id project_nr project_name workflow_key return_url project_id}]
        } else {
            ad_returnredirect [export_vars -base "/intranet-translation/projects/new" -url {project_type_id project_status_id company_id parent_id project_nr project_name workflow_key return_url project_id}]
        }   
    }
}
