# /packages/intranet-translation/tcl/intranet-tandem-procs.tcl
#
# Copyright (C) 2004-2009 ]project-open[
#
# All rights reserved (this is not GPLed software!).
# Please check http://www.project-open.com/ for licensing
# details.

ad_library {
    Specific stuff for translation handling and  PO creation 

    @author malte.sussdorff@cognovis.de
    
}

ad_proc -public im_translation_best_rate {
    -provider_id
    -task_type_id
    {-subject_area_id ""}
    -target_language_id
    -source_language_id
    {-currency "EUR"}
    -task_uom_id
} {
    Calculate the best rate for freelancers
} {
    set number_format "9999990.099"

    return [db_string best_rate "
    select 
        to_char(pr.price, :number_format) as price
    from
        (
            (select 
                im_trans_prices_calc_relevancy (
                    p.company_id, :provider_id,
                    p.task_type_id, :task_type_id,
                    p.subject_area_id, :subject_area_id,
                    p.target_language_id, :target_language_id,
                    p.source_language_id, :source_language_id
                ) as relevancy,
                p.price_id,
                p.price,
                p.company_id as company_id,
                p.uom_id,
                p.task_type_id,
                p.target_language_id,
                p.source_language_id,
                p.subject_area_id,
                p.valid_from,
                p.valid_through,
                p.note as price_note
            from im_trans_prices p
            where
                uom_id=:task_uom_id
                and currency = :currency
                and p.company_id not in (
                    select company_id
                    from im_companies
                    where company_path = 'internal'
                )

            )
        ) pr
          LEFT JOIN
        im_companies c ON pr.company_id = c.company_id
    where
            relevancy >= 0
    order by
        pr.relevancy desc,
        pr.company_id,
        pr.uom_id
    limit 1
    " -default 0]
}


ad_proc -public im_translation_create_purchase_orders {
    -project_id
    {-target_cost_type_id 0}
    {-target_cost_status_id 0}
    {-cost_center_id ""}
    {-rate_array ""}
} {
    Create the purchase orders for a project or all tasks which do not have a 
    purchase order created yet
    
    @param rate_array Array in the form ${task_type_id}_${task_uom_id}_${freelance_id} for the key and the actual rate for this combination as the value
} {
    # ---------------------------------------------------------------
    # Defaults & Security
    # ---------------------------------------------------------------

    set user_id [ad_maybe_redirect_for_registration]

    if {0 == $target_cost_status_id} { set target_cost_status_id [im_cost_status_created] }
    if {0 == $target_cost_type_id} { set target_cost_type_id [im_cost_type_po] }

    set cost_status_id $target_cost_status_id

    set todays_date [db_string get_today "select to_char(sysdate,'YYYY-MM-DD') from dual"]

    set user_locale [lang::user::locale]
    set locale $user_locale

    set im_material_default_translation_material_id [im_material_default_translation_material_id]


    # ---------------------------------------------------------------
    # Get a list of all freelancers working on this project
    # ---------------------------------------------------------------

    set subprojects [db_list subprojects "
        select	children.project_id
        from	im_projects parent,
            im_projects children
        where
            children.project_status_id not in ([join [im_sub_categories [im_project_status_closed]] ","])
            and children.tree_sortkey 
                between parent.tree_sortkey 
                and tree_right(parent.tree_sortkey)
            and parent.project_id = :project_id
    "]



    lappend subprojects 0
    set subproject_sql "([join $subprojects ", "])"

    set task_sql "
    select distinct
        pe.person_id as freelance_id,
        im_name_from_user_id (pe.person_id) as freelance_name,
        im_category_from_id(m.object_role_id) as role,
        im_category_from_id(tt.source_language_id) as source_language,
        im_category_from_id(tt.target_language_id) as target_language,
        p.subject_area_id,
        im_category_from_id(tt.task_uom_id) as task_uom,
        im_category_from_id(tt.task_status_id) as task_status,
        tt.*
    from
        acs_rels r,
        im_biz_object_members m,
        (
            select
                tt.trans_id as freelance_id,
                'trans' as action,
                            trans_end_date as delivery_date,
                            end_date,
                [im_project_type_trans] as po_task_type_id,
                im_category_from_id([im_project_type_trans]) as po_task_type,
                tt.*
              from	im_trans_tasks tt
              where	tt.project_id in $subproject_sql
                and tt.trans_id is not null
          UNION
            select
                tt.edit_id as freelance_id,
                'edit' as action,
                            edit_end_date as delivery_date,
                            end_date,
                [im_project_type_edit] as po_task_type_id,
                im_category_from_id([im_project_type_edit]) as po_task_type,
                tt.*
              from	im_trans_tasks tt
              where	tt.project_id in $subproject_sql
                and tt.edit_id is not null
          UNION
            select
                tt.proof_id as freelance_id,
                'proof' as action,
                            proof_end_date as delivery_date,
                            end_date,
                [im_project_type_proof] as po_task_type_id,
                im_category_from_id([im_project_type_proof]) as po_task_type,
                tt.*
              from	im_trans_tasks tt
              where	tt.project_id in $subproject_sql
                and tt.proof_id is not null
          UNION
            select
                tt.other_id as freelance_id,
                'other' as action,
                            other_end_date as delivery_date,
                            end_date,
                [im_project_type_other] as po_task_type_id,
                im_category_from_id([im_project_type_other]) as po_task_type,
                tt.*
              from	im_trans_tasks tt
              where	tt.project_id in $subproject_sql
                and tt.other_id is not null
        ) tt,
        persons pe,
        im_projects p,
        group_distinct_member_map fmem
    where
        r.object_id_one = p.project_id
        and p.project_id in $subproject_sql
        and r.rel_id = m.rel_id
        and r.object_id_two = pe.person_id
        and fmem.group_id = [im_freelance_group_id]
        and pe.person_id = fmem.member_id
        and pe.person_id = tt.freelance_id
    order by
        tt.freelance_id
    "

    # ---------------------------------------------------------------
    # Get the billable units and units of measure
    # ---------------------------------------------------------------

    set editing_words_per_hour [ad_parameter -package_id [im_package_freelance_invoices_id] "EditingWordsPerHour" "" 1000]
    set freelance_ids [list]

    db_foreach task_tasks $task_sql {

       set file_type_id ""
       set task_type_id $po_task_type_id
       set material_id [im_material_create_from_parameters -material_uom_id $task_uom_id -material_type_id [im_material_type_translation]]

        set po_created_p [db_string po_created "select i.invoice_id from im_invoice_items ii, im_invoices i where task_id = :task_id and company_contact_id = :freelance_id and item_material_id = :material_id limit 1" -default 0]

        if {!$po_created_p} {
            lappend po_task_ids($freelance_id) $task_id
            if {[lsearch $freelance_ids $freelance_id]<0} {
                lappend freelance_ids $freelance_id

                set provider_id [db_string select_company { 
                    select  c.company_id as provider_id
                    from	    acs_rels r,
                            im_companies c
                    where	r.object_id_one = c.company_id
                    and     r.object_id_two = :freelance_id
                    limit 1
                } -default 0]
                set provider($freelance_id) $provider_id
            }

            # ---------------------------------------------------------------
            # Get the billable units
            # ---------------------------------------------------------------

            switch $action {
                trans {
                    array set provider_matrix [im_trans_trados_matrix $provider_id]

                    db_1row billable_units "
                                        select (tt.match_x * $provider_matrix(x) +
                                                tt.match_rep * $provider_matrix(rep) +
                                                tt.match_perf * $provider_matrix(perf) +
                                                tt.match_cfr * $provider_matrix(cfr) +
                                                tt.match100 * $provider_matrix(100) +
                                                tt.match95 * $provider_matrix(95) +
                                                tt.match85 * $provider_matrix(85) +
                                                tt.match75 * $provider_matrix(75) +
                                                tt.match50 * $provider_matrix(50) +
                                                tt.match0 * $provider_matrix(0) +
                                                tt.match_f95 * $provider_matrix(f95) +
                                                tt.match_f85 * $provider_matrix(f85) +
                                                tt.match_f75 * $provider_matrix(f75) +
                                                tt.match_f50 * $provider_matrix(f50)
                                            )   as po_billable_units, 
                                            tt.task_uom_id as po_task_uom_id
                                        from im_trans_tasks tt
                                        where task_id = :task_id
                                        and (
                                                tt.task_uom_id = [im_uom_s_word]
                                                and tt.match100 is not null
                                            )
                                        UNION 
                                        select tt.task_units as po_billable_units,
                                               tt.task_uom_id as po_task_uom_id
                                        from	im_trans_tasks tt
                                        where task_id = :task_id
                                        and (
                                            tt.task_uom_id != [im_uom_s_word]
                                            or tt.match100 is null
                                        )
                                    "
                }
                edit {
                    db_1row billable_units "
                            select (	tt.match_x +
                                    tt.match_rep +
                                    tt.match_perf +
                                    tt.match_cfr +
                                    tt.match100 +
                                    tt.match95 +
                                    tt.match85 +
                                    tt.match75 +
                                    tt.match50 +
                                    tt.match0 +
                                    tt.match_f95 +
                                    tt.match_f85 +
                                    tt.match_f75 +
                                    tt.match_f50

                                ) / $editing_words_per_hour as po_billable_units,
                            [im_uom_hour] as po_task_uom_id
                        from	   im_trans_tasks tt
                        where   tt.task_id = :task_id
                            and (
                                tt.task_uom_id = [im_uom_s_word]
                                and tt.match100 is not null
                            )
                    UNION
                        select tt.task_units as po_billable_units,
                            tt.task_uom_id as po_task_uom_id
                        from	im_trans_tasks tt
                        where	tt.task_id = :task_id
                            and (
                                tt.task_uom_id != [im_uom_s_word]
                                or tt.match100 is null
                            )
                    "
                }
                proof - other {
                    db_1row billable_units "
                            select  tt.billable_units as po_billable_units,
                                    tt.task_uom_id as po_task_uom_id
                            from    im_trans_tasks tt
                            where   tt.task_id = :task_id"
                }
            }
            if {[info exists task_types(${task_id}_${freelance_id})]} {
                lappend task_types(${task_id}_${freelance_id}) $po_task_type_id
            } else {
                set task_types(${task_id}_${freelance_id}) [list $po_task_type_id]
            }
            
            
            set create_line_item(${task_id}_${po_task_type_id}_${freelance_id}) 1
            set billable_units_task(${task_id}_${po_task_type_id}_${freelance_id}) $po_billable_units
            set uom(${task_id}_${po_task_type_id}_${freelance_id}) $po_task_uom_id

            set subject_area($task_id) $subject_area_id
            set source_language_task($task_id) $source_language_id
            set target_language_task($task_id) $target_language_id

            # Title is there - add specifics
            switch $po_task_type_id {
                86 {
                    set task_date_pretty [lc_time_fmt $other_end_date "%x %X" $locale]
                    set end_date $other_end_date
                }
                88 {
                    set task_date_pretty [lc_time_fmt $edit_end_date "%x %X" $locale]
                    set end_date $edit_end_date
                }
                93 {
                    set task_date_pretty [lc_time_fmt $trans_end_date "%x %X" $locale]
                    set end_date $trans_end_date
                }
                95 {
                    set task_date_pretty [lc_time_fmt $proof_end_date "%x %X" $locale]
                    set end_date $proof_end_date
                }	
                default {set task_date_pretty [lc_time_fmt $end_date "%x %X" $locale]}
            }

            set task_title(${task_id}_${po_task_type_id}_${freelance_id}) "$po_task_type: $task_name ($source_language -> $target_language) Deadline: \"$task_date_pretty CET\""

            # Maybe we need the end date in the purchase order later
            set task_end_date(${task_id}_${po_task_type_id}_${freelance_id}) $end_date

        }
    }

    # ---------------------------------------------------------------
    # Loop through each freelancer to create the purchase orders
    # ---------------------------------------------------------------

    set created_invoice_ids [list]

    # Check if we have a rate array which would not get the rates from the database
    if {"" != $rate_array} {
        upvar $rate_array rates
    }    

    foreach freelance_id $freelance_ids {

        # ---------------------------------------------------------------
        # If we have tasks needing a purchase order, create the order first
        # ---------------------------------------------------------------

        if {[llength $po_task_ids($freelance_id)] == 0} {continue}

        # create the purchase order
        set invoice_nr [im_next_invoice_nr -cost_type_id $target_cost_type_id -cost_center_id $cost_center_id]
        set invoice_id [im_new_object_id]
        set company_id [im_company_internal]
        set provider_id $provider($freelance_id)

        # Check if we have a company for this freelancer, otherwise we can't create the purchase order
        if { 0 == $provider_id } { continue }

        db_1row select_company {
                select  company_id as provider_id,
                        default_vat,
                        default_tax,
                        default_payment_method_id,
                        default_po_template_id,
                        payment_term_id,
                        vat_type_id
                from	    im_companies c
                where	company_id = :provider_id
        }   


        if {"" == $default_po_template_id} {
            # Get a sensible default
            set template_id [db_string internal_template "select default_po_template_id from im_companies where company_id = :company_id" -default ""]
        } else {
            set template_id $default_po_template_id
        }

        # Get the payment days from the company
        set payment_days [ad_parameter -package_id [im_package_cost_id] "DefaultCompanyInvoicePaymentDays" "" 30] 
        set tax_format [im_l10n_sql_currency_format -style simple]
        set note ""

        # Find the currency for the provider by looking at the prices
        set currency ""
        db_0or1row currency "select currency, count(*) as num_prices from im_trans_prices where company_id = :provider_id group by currency order by num_prices desc limit 1"

        if {$currency eq ""} {
            set currency [ad_parameter -package_id [im_package_cost_id] "DefaultCurrency" "" "EUR"]     
        } 



        db_transaction {
            set invoice_id [db_exec_plsql create_invoice {
                    select im_invoice__new (
                        :invoice_id,		-- invoice_id
                        'im_invoice',		-- object_type
                        now(),			-- creation_date 
                        :user_id,		-- creation_user
                        '[ad_conn peeraddr]',	-- creation_ip
                        null,			-- context_id
                        :invoice_nr,		-- invoice_nr
                        :company_id,		-- company_id
                        :provider_id,	-- provider_id
                        :freelance_id,	-- company_contact_id
                        now(),		    -- invoice_date
                        :currency,			-- currency
                        :template_id,	-- invoice_template_id
                        :target_cost_status_id,	-- invoice_status_id
                        :target_cost_type_id,		-- invoice_type_id
                        :default_payment_method_id,	-- payment_method_id
                        :payment_days,		-- payment_days
                        0,			    -- amount
                        to_number(:default_vat,:tax_format),			-- vat
                        to_number(:default_tax,:tax_format),			-- tax
                        :note			-- note
                    )
            }]


            db_dml update_costs "
            update im_costs
            set
                project_id	= :project_id,
                cost_name	= :invoice_nr,
                customer_id	= :company_id,
                cost_nr		= :invoice_id,
                provider_id	= :provider_id,
                cost_status_id	= :target_cost_status_id,
                cost_type_id	= :target_cost_type_id,
                cost_center_id	= :cost_center_id,
                template_id	= :template_id,
                payment_days	= :payment_days,
                vat		= to_number(:default_vat,:tax_format),
                tax		= to_number(:default_tax,:tax_format),
                variable_cost_p = 't',
                currency	= :currency,
                payment_term_id = :payment_term_id,
                vat_type_id     = :vat_type_id
            where
                cost_id = :invoice_id
            "

            # Add the link between the project and the invoice
            set rel_id [db_exec_plsql create_rel "      select acs_rel__new (
                 null,             -- rel_id
                 'relationship',   -- rel_type
                 :project_id,      -- object_id_one
                 :invoice_id,      -- object_id_two
                 null,             -- context_id
                 null,             -- creation_user
                 null             -- creation_ip
          )"]

            lappend created_invoice_ids $invoice_id
            # ---------------------------------------------------------------
            # Create the line items
            # ---------------------------------------------------------------
            set sort_order 0
            set delivery_date ""
                        
            foreach task_id [lsort -unique $po_task_ids($freelance_id)] {
                foreach task_type_id $task_types(${task_id}_${freelance_id}) {
                    # We need to create the line items for all task_types and tasks
                    # But only if we really need to create it.....
                    if {[info exists create_line_item(${task_id}_${task_type_id}_${freelance_id})]} {
                        ds_comment "create_line_item(${task_id}_${task_type_id}_${freelance_id}) :: $create_line_item(${task_id}_${task_type_id}_${freelance_id})"
                        set source_language_id $source_language_task($task_id)
                        set target_language_id $target_language_task($task_id)
                        set task_uom_id $uom(${task_id}_${task_type_id}_${freelance_id})
                        set item_units $billable_units_task(${task_id}_${task_type_id}_${freelance_id})
                        set item_name $task_title(${task_id}_${task_type_id}_${freelance_id})
        
                        if {[info exists rates(${task_type_id}_${task_uom_id}_${freelance_id})]} {
                            set rate $rates(${task_type_id}_${task_uom_id}_${freelance_id})                    
                        } else {
                            # Get the price from the database
                            set rate [im_translation_best_rate -provider_id $provider_id -task_type_id $task_type_id -subject_area_id $subject_area($task_id) -target_language_id $target_language_id -source_language_id $source_language_id -task_uom_id $task_uom_id -currency $currency]
                        }
    
                        set file_type_id ""
                        set material_id [im_material_create_from_parameters -material_uom_id $task_uom_id -material_type_id [im_material_type_translation]]
        
                        # Deal with the end date
                        # Make the last end date the delivery date for the purchase order
                        if {$delivery_date < $task_end_date(${task_id}_${task_type_id}_${freelance_id})} {set delivery_date $task_end_date(${task_id}_${task_type_id}_${freelance_id})}
                        incr sort_order
    
                        if {!(0 == $item_units || "" == $item_units)} {
                            set item_id [db_nextval "im_invoice_items_seq"]
                            set source_invoice_id -1
                            set insert_invoice_items_sql "
                                    INSERT INTO im_invoice_items (
                                            item_id, item_name,
                                            project_id, invoice_id,
                                            item_units, item_uom_id,
                                            price_per_unit, currency,
                                            sort_order, item_type_id,
                                            item_material_id,
                                            item_status_id, description, task_id,
                                            item_source_invoice_id
                                    ) VALUES (
                                            :item_id, :item_name,
                                            :project_id, :invoice_id,
                                            :item_units, :task_uom_id,
                                            :rate, :currency,
                                            :sort_order, :task_type_id,
                                            :material_id,
                                            null, '', :task_id,
                                            null
                                )" 
    
    
                            db_dml insert_invoice_items $insert_invoice_items_sql
                        }
                    }
                }
            
            }

            # Recalculate and update the invoice amount
            im_invoice_update_rounded_amount \
            -invoice_id $invoice_id \
            -discount_perc 0 \
            -surcharge_perc 0

            # Update the delivery_date
            db_dml update_delivery_date "update im_costs set delivery_date = :delivery_date where cost_id = :invoice_id"
        }
        im_audit -object_type "im_invoice" -object_id $invoice_id -action after_create -status_id $target_cost_status_id -type_id $target_cost_type_id
    }
    return "$created_invoice_ids"
}

