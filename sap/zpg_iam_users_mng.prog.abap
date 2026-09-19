*&---------------------------------------------------------------------*
*& Report ZPG_IAM_USERS_MNG
*& User Status & Authorization Management
*&---------------------------------------------------------------------*
REPORT zpg_iam_users_mng.

TABLES: usr02.

SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-001.
  SELECT-OPTIONS: s_bname FOR usr02-bname,
                  s_erdat FOR usr02-erdat,
                  s_trdat FOR usr02-trdat OBLIGATORY DEFAULT sy-datum.
SELECTION-SCREEN END OF BLOCK b1.

SELECTION-SCREEN BEGIN OF BLOCK b2 WITH FRAME TITLE TEXT-002.
  PARAMETERS: p_act  TYPE c AS CHECKBOX DEFAULT 'X',
              p_dact TYPE c AS CHECKBOX DEFAULT 'X'.
SELECTION-SCREEN END OF BLOCK b2.

TYPES:
  BEGIN OF gty_alv,
    flag        TYPE c,
    bname       TYPE usr02-bname,
    fname       TYPE ad_namtext,
    erdat       TYPE xuerdat,
    trdat       TYPE xuldate,
    ltime       TYPE xultime,
    erdat_text  TYPE char10,
    trdat_text  TYPE char10,
    ltime_text  TYPE char8,
    uflag       TYPE xuuflag,
    user_status TYPE char10,
    department  TYPE ad_dprtmnt,
    email             TYPE ad_smtpadr,
    last_action       TYPE char40,
    last_changed_by   TYPE xubname,
    last_changed_at   TYPE char19,
    audit_count       TYPE i,
    last_req_id       TYPE char20,
    last_req_status   TYPE char20,
    last_req_by       TYPE xubname,
    last_req_at       TYPE char19,
    approved_by       TYPE xubname,
    last_req_changed  TYPE char19,
    pending_req_count TYPE i,
    color             TYPE lvc_t_scol,
  END OF gty_alv.

TYPES:
  BEGIN OF gty_role,
    flag     TYPE c,
    bname    TYPE usr02-bname,
    agr_name TYPE agr_name,
    from_dat TYPE dats,
    to_dat   TYPE dats,
  END OF gty_role.

TYPES:
  BEGIN OF gty_audit,
    log_id        TYPE c LENGTH 36,
    target_user   TYPE xubname,
    action_type   TYPE char20,
    performed_by  TYPE xubname,
    old_value     TYPE char255,
    new_value     TYPE char255,
    timestamp     TYPE timestampl,
    action_text   TYPE char40,
    timestamp_text TYPE char19,
    source_module TYPE char10,
  END OF gty_audit.

TYPES:
  BEGIN OF gty_request,
    target_user      TYPE xubname,
    req_id           TYPE char20,
    status           TYPE char2,
    requested_by     TYPE xubname,
    created_by       TYPE xubname,
    approved_by      TYPE xubname,
    created_at       TYPE timestampl,
    last_changed_at  TYPE timestampl,
  END OF gty_request.

DATA: gt_alv   TYPE TABLE OF gty_alv,
      gt_roles TYPE TABLE OF gty_role,
      gt_audit TYPE TABLE OF gty_audit.

DATA: go_grid TYPE REF TO cl_gui_alv_grid,
      go_falv TYPE REF TO zcl_falv.

DATA: gt_fcat    TYPE lvc_t_fcat,
      gs_layout  TYPE lvc_s_layo,
      gt_exclude TYPE slis_t_extab,
      gs_variant TYPE disvariant,
      gv_header_text TYPE char70.

DATA: gt_return TYPE TABLE OF bapiret2,
      gt_tab    TYPE esp1_message_tab_type,
      gs_tab    TYPE esp1_message_wa_type.

DATA: gv_ok_code TYPE sy-ucomm.
DATA gv_timezone TYPE timezone.
*&---------------------------------------------------------------------*
*& Include ZPG_IAM_RUSERS_SOD_I01
*& Global declarations plus SoD review forms for ZPG_RUSERS_02
*& This include is placed after global DATA and before the local class.
*&---------------------------------------------------------------------*

*& Include ZPG_RUSERS_02_SOD_TYPES
TYPES:
  BEGIN OF gty_iam_sod_popup,
    flag             TYPE c,
    target_user      TYPE xubname,
    rule_id          TYPE char20,
    rule_name        TYPE char100,
    risk_level       TYPE char1,
    role_1           TYPE agr_name,
    role_2           TYPE agr_name,
    is_exempt        TYPE abap_bool,
    exempt_reason    TYPE char255,
    suggested_action TYPE char255,
    is_locked        TYPE abap_bool,
    last_login       TYPE xuldate,
  END OF gty_iam_sod_popup.

*& Include ZPG_RUSERS_02_SOD_FORMS
*& SoD check and controlled role-removal extension for ZPG_RUSERS_02
FORM check_sod.
  DATA lv_valid TYPE c.
  DATA lt_users TYPE zcl_iam_sod_admin=>tt_user.
  DATA lt_conflicts TYPE zcl_iam_sod_admin=>tt_conflict.
  DATA lt_popup TYPE STANDARD TABLE OF gty_iam_sod_popup WITH EMPTY KEY.
  DATA lt_fcat TYPE slis_t_fieldcat_alv.
  DATA ls_fcat TYPE slis_fieldcat_alv.
  DATA lv_exit TYPE c.

  go_grid->check_changed_data( IMPORTING e_valid = lv_valid ).
  LOOP AT gt_alv INTO DATA(ls_user) WHERE flag = 'X'.
    INSERT ls_user-bname INTO TABLE lt_users.
  ENDLOOP.
  IF lt_users IS INITIAL.
    MESSAGE s011(zmsg_iam07) DISPLAY LIKE 'W'.
    RETURN.
  ENDIF.

  lt_conflicts = zcl_iam_sod_admin=>scan_users( lt_users ).
  LOOP AT lt_conflicts INTO DATA(ls_conflict).
    APPEND CORRESPONDING #( ls_conflict ) TO lt_popup.
  ENDLOOP.
  IF lt_popup IS INITIAL.
    MESSAGE s023(zmsg_iam07).
    RETURN.
  ENDIF.

  CLEAR ls_fcat. ls_fcat-fieldname = 'FLAG'. ls_fcat-seltext_l = 'Review'.
  ls_fcat-checkbox = 'X'. ls_fcat-edit = 'X'. ls_fcat-outputlen = 6. APPEND ls_fcat TO lt_fcat.
  CLEAR ls_fcat. ls_fcat-fieldname = 'TARGET_USER'. ls_fcat-seltext_l = 'User'.
  ls_fcat-outputlen = 12. APPEND ls_fcat TO lt_fcat.
  CLEAR ls_fcat. ls_fcat-fieldname = 'RULE_ID'. ls_fcat-seltext_l = 'Rule'.
  ls_fcat-outputlen = 12. APPEND ls_fcat TO lt_fcat.
  CLEAR ls_fcat. ls_fcat-fieldname = 'RISK_LEVEL'. ls_fcat-seltext_l = 'Risk'.
  ls_fcat-outputlen = 6. APPEND ls_fcat TO lt_fcat.
  CLEAR ls_fcat. ls_fcat-fieldname = 'ROLE_1'. ls_fcat-seltext_l = 'Role 1'.
  ls_fcat-outputlen = 30. APPEND ls_fcat TO lt_fcat.
  CLEAR ls_fcat. ls_fcat-fieldname = 'ROLE_2'. ls_fcat-seltext_l = 'Role 2'.
  ls_fcat-outputlen = 30. APPEND ls_fcat TO lt_fcat.
  CLEAR ls_fcat. ls_fcat-fieldname = 'IS_EXEMPT'. ls_fcat-seltext_l = 'Exempt'.
  ls_fcat-checkbox = 'X'. ls_fcat-outputlen = 7. APPEND ls_fcat TO lt_fcat.
  CLEAR ls_fcat. ls_fcat-fieldname = 'SUGGESTED_ACTION'. ls_fcat-seltext_l = 'Action'.
  ls_fcat-outputlen = 15. APPEND ls_fcat TO lt_fcat.
  CLEAR ls_fcat. ls_fcat-fieldname = 'LAST_LOGIN'. ls_fcat-seltext_l = 'Last logon'.
  ls_fcat-outputlen = 12. APPEND ls_fcat TO lt_fcat.

  CALL FUNCTION 'REUSE_ALV_POPUP_TO_SELECT'
    EXPORTING
      i_title              = 'SoD conflicts - select one item to review'
      i_selection          = 'X'
      i_zebra              = 'X'
      i_checkbox_fieldname = 'FLAG'
      i_tabname            = 'LT_POPUP'
      it_fieldcat          = lt_fcat
    IMPORTING
      e_exit               = lv_exit
    TABLES
      t_outtab             = lt_popup.
  IF lv_exit = 'X'.
    RETURN.
  ENDIF.

  LOOP AT lt_popup INTO DATA(ls_popup) WHERE flag = 'X'.
    PERFORM review_sod_conflict USING ls_popup.
  ENDLOOP.
ENDFORM.

FORM review_sod_conflict USING ps_conflict TYPE gty_iam_sod_popup.
  TYPES:
    BEGIN OF ty_role_choice,
      selected TYPE c,
      role     TYPE agr_name,
    END OF ty_role_choice.
  DATA lt_role_choice TYPE STANDARD TABLE OF ty_role_choice WITH EMPTY KEY.
  DATA lt_role_fcat TYPE slis_t_fieldcat_alv.
  DATA ls_role_fcat TYPE slis_fieldcat_alv.
  DATA lt_fields TYPE STANDARD TABLE OF sval WITH EMPTY KEY.
  DATA lv_popup_exit TYPE c.
  DATA lv_selected_count TYPE i.
  DATA lv_role TYPE agr_name.
  DATA lv_answer TYPE c.
  DATA lv_success TYPE abap_bool.
  DATA lv_message TYPE string.
  DATA lv_question TYPE string.

  IF ps_conflict-is_exempt = abap_true.
    MESSAGE s024(zmsg_iam07) WITH ps_conflict-rule_id DISPLAY LIKE 'W'.
    RETURN.
  ENDIF.

  APPEND VALUE #( role = ps_conflict-role_1 ) TO lt_role_choice.
  APPEND VALUE #( role = ps_conflict-role_2 ) TO lt_role_choice.
  CLEAR ls_role_fcat. ls_role_fcat-fieldname = 'SELECTED'. ls_role_fcat-seltext_l = 'Remove'.
  ls_role_fcat-checkbox = 'X'. ls_role_fcat-edit = 'X'. ls_role_fcat-outputlen = 8.
  APPEND ls_role_fcat TO lt_role_fcat.
  CLEAR ls_role_fcat. ls_role_fcat-fieldname = 'ROLE'. ls_role_fcat-seltext_l = 'Conflicting role'.
  ls_role_fcat-outputlen = 40. APPEND ls_role_fcat TO lt_role_fcat.

  CALL FUNCTION 'REUSE_ALV_POPUP_TO_SELECT'
    EXPORTING
      i_title              = |Choose one role to remove - rule { ps_conflict-rule_id }|
      i_selection          = 'X'
      i_zebra              = 'X'
      i_checkbox_fieldname = 'SELECTED'
      i_tabname            = 'LT_ROLE_CHOICE'
      it_fieldcat          = lt_role_fcat
    IMPORTING
      e_exit               = lv_popup_exit
    TABLES
      t_outtab             = lt_role_choice.
  IF lv_popup_exit = 'X'.
    RETURN.
  ENDIF.

  LOOP AT lt_role_choice INTO DATA(ls_role_choice) WHERE selected = 'X'.
    lv_selected_count = lv_selected_count + 1.
    lv_role = ls_role_choice-role.
  ENDLOOP.
  IF lv_selected_count <> 1.
    MESSAGE s022(zmsg_iam07) DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  APPEND VALUE #( tabname = 'ZIAM_AUD_LOG2' fieldname = 'NEW_VALUE'
                  fieldtext = 'Review reason' field_obl = 'X' ) TO lt_fields.
  CALL FUNCTION 'POPUP_GET_VALUES'
    EXPORTING popup_title = |Review SoD rule { ps_conflict-rule_id }|
    TABLES    fields      = lt_fields
    EXCEPTIONS
      error_in_fields = 1
      OTHERS          = 2.
  IF sy-subrc <> 0.
    RETURN.
  ENDIF.
  READ TABLE lt_fields INDEX 1 INTO DATA(ls_reason).
  IF ls_reason-value IS INITIAL.
    MESSAGE s021(zmsg_iam07) DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  MESSAGE ID 'ZMSG_IAM07' TYPE 'S' NUMBER '025'
    WITH lv_role ps_conflict-target_user INTO lv_question.

  CALL FUNCTION 'POPUP_TO_CONFIRM'
    EXPORTING
      titlebar              = 'Confirm SoD remediation'
      text_question         = lv_question
      text_button_1         = 'Remove role'
      icon_button_1         = 'ICON_DELETE'
      text_button_2         = 'Cancel'
      default_button        = '2'
      display_cancel_button = abap_true
    IMPORTING
      answer                = lv_answer.
  IF lv_answer <> '1'.
    RETURN.
  ENDIF.

  zcl_iam_sod_admin=>remove_conflict_role(
    EXPORTING
      iv_user    = ps_conflict-target_user
      iv_rule_id = ps_conflict-rule_id
      iv_role    = lv_role
      iv_reason  = CONV char255( ls_reason-value )
    IMPORTING
      ev_success = lv_success
      ev_message = lv_message ).

  IF lv_success = abap_true.
    MESSAGE lv_message TYPE 'S'.
  ELSE.
    MESSAGE lv_message TYPE 'S' DISPLAY LIKE 'E'.
  ENDIF.
ENDFORM.

CLASS lcl_alv_events DEFINITION.
  PUBLIC SECTION.
    CLASS-METHODS on_user_command FOR EVENT user_command OF cl_gui_alv_grid
      IMPORTING e_ucomm.
    CLASS-METHODS on_top_of_page FOR EVENT top_of_page OF cl_gui_alv_grid
      IMPORTING e_dyndoc_id.
ENDCLASS.

CLASS lcl_alv_events IMPLEMENTATION.
  METHOD on_user_command.
    DATA lv_ucomm TYPE sy-ucomm.
    lv_ucomm = e_ucomm.
    CASE e_ucomm.
      WHEN 'F01'. lv_ucomm = 'ALL'.
      WHEN 'F02'. lv_ucomm = 'DALL'.
      WHEN 'F03'. lv_ucomm = 'LOCK'.
      WHEN 'F04'. lv_ucomm = 'UNLOCK'.
      WHEN 'F05'. lv_ucomm = 'CHECK_AUTH'.
      WHEN 'F06'. lv_ucomm = 'REMOVE_AUTH'.
      WHEN 'F07'. lv_ucomm = 'CHECK_SOD'.
      WHEN 'F08'. lv_ucomm = 'AUDIT'.
    ENDCASE.
    PERFORM handle_alv_ucomm USING lv_ucomm.
  ENDMETHOD.
  METHOD on_top_of_page.
    DATA: lv_run_ts TYPE timestampl,
          lv_run_at TYPE char19,
          lv_run_date TYPE char10,
          lv_run_time TYPE char8,
          lv_records TYPE i,
          lv_status_filter TYPE char30,
          lv_line TYPE sdydo_text_element.

    IF e_dyndoc_id IS NOT BOUND.
      RETURN.
    ENDIF.

    GET TIME STAMP FIELD lv_run_ts.
    PERFORM format_timestamp USING lv_run_ts CHANGING lv_run_at.
    lv_run_date = lv_run_at+0(10).
    lv_run_time = lv_run_at+11(8).
    DESCRIBE TABLE gt_alv LINES lv_records.

    IF p_act = 'X' AND p_dact = 'X'.
      lv_status_filter = 'Active + Inactive'.
    ELSEIF p_act = 'X'.
      lv_status_filter = 'Active only'.
    ELSEIF p_dact = 'X'.
      lv_status_filter = 'Inactive only'.
    ELSE.
      lv_status_filter = 'No status selected'.
    ENDIF.

    e_dyndoc_id->add_text( text = 'IAM User Management'
                           sap_style = cl_dd_area=>heading ).
    e_dyndoc_id->new_line( ).
    lv_line = |Run at: { lv_run_date }|.
    e_dyndoc_id->add_text( text = lv_line sap_style = cl_dd_area=>strong ).
    e_dyndoc_id->new_line( ).
    lv_line = |Run time: { lv_run_time }|.
    e_dyndoc_id->add_text( text = lv_line ).
    e_dyndoc_id->new_line( ).
    lv_line = |Run by: { sy-uname }|.
    e_dyndoc_id->add_text( text = lv_line ).
    e_dyndoc_id->new_line( ).
    lv_line = |Records: { lv_records }|.
    e_dyndoc_id->add_text( text = lv_line ).
    e_dyndoc_id->new_line( ).
    lv_line = |Status filter: { lv_status_filter }|.
    e_dyndoc_id->add_text( text = lv_line ).
    e_dyndoc_id->new_line( ).
    lv_line = |Overview: { gv_header_text }|.
    e_dyndoc_id->add_text( text = lv_line ).
  ENDMETHOD.
ENDCLASS.

* lcl_role_events removed - Remove Auth now uses REUSE_ALV_POPUP_TO_SELECT

START-OF-SELECTION.
  PERFORM get_data.
  IF gt_alv IS NOT INITIAL.
    PERFORM display_alv.
  ELSE.
    MESSAGE i012(zmsg_iam07) DISPLAY LIKE 'E'.
  ENDIF.
FORM display_alv.
  PERFORM build_fieldcat.
  PERFORM set_layout.
  PERFORM set_toolbar_exclude.

  go_falv = zcl_falv=>create( CHANGING ct_table = gt_alv ).
  IF go_falv IS NOT BOUND.
    MESSAGE s012(zmsg_iam07) DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  go_grid = go_falv.
  go_falv->fcat = gt_fcat.
  go_falv->set_frontend_fieldcatalog( it_fieldcatalog = gt_fcat ).
  go_falv->variant = gs_variant.
  go_falv->layout_save = 'A'.
  go_falv->layout->set_zebra( gs_layout-zebra ).
  go_falv->layout->set_sel_mode( gs_layout-sel_mode ).
  go_falv->layout->set_cwidth_opt( abap_false ).
* Show the standard ALV grid toolbar directly above the table.
  go_falv->layout->set_no_toolbar( abap_false ).
* Hide only ALV local editing (CRUD) actions; keep analytical functions.
  go_falv->exclude_functions = VALUE ui_functions(
    ( cl_gui_alv_grid=>mc_fc_loc_insert_row )
    ( cl_gui_alv_grid=>mc_fc_loc_append_row )
    ( cl_gui_alv_grid=>mc_fc_loc_delete_row )
    ( cl_gui_alv_grid=>mc_fc_loc_copy )
    ( cl_gui_alv_grid=>mc_fc_loc_copy_row )
    ( cl_gui_alv_grid=>mc_fc_loc_cut )
    ( cl_gui_alv_grid=>mc_fc_loc_paste )
    ( cl_gui_alv_grid=>mc_fc_loc_paste_new_row )
    ( cl_gui_alv_grid=>mc_fc_loc_move_row )
    ( cl_gui_alv_grid=>mc_fc_loc_undo ) ).
  go_falv->layout->set_grid_title( gv_header_text ).

  SET HANDLER lcl_alv_events=>on_user_command FOR go_falv.
  SET HANDLER lcl_alv_events=>on_top_of_page FOR go_falv.

* Keep the dynamic screen status for the business actions; standard ALV
* functions are provided by the grid toolbar above the table.
  go_falv->gui_status->fully_dynamic = abap_true.
  go_falv->gui_status->add_button( iv_button = 'F01' iv_text = 'Select All'
                                   iv_icon = icon_select_all iv_qinfo = 'Select all users' ).
  go_falv->gui_status->add_button( iv_button = 'F02' iv_text = 'Deselect All'
                                   iv_icon = icon_deselect_all iv_qinfo = 'Deselect all users' ).
  go_falv->gui_status->add_button( iv_button = 'F03' iv_text = 'Lock'
                                   iv_icon = icon_locked iv_qinfo = 'Lock selected users' ).
  go_falv->gui_status->add_button( iv_button = 'F04' iv_text = 'Unlock'
                                   iv_icon = icon_unlocked iv_qinfo = 'Unlock selected users' ).
  go_falv->gui_status->add_button( iv_button = 'F05' iv_text = 'Check Auth'
                                   iv_icon = icon_check iv_qinfo = 'Check selected user roles' ).
  go_falv->gui_status->add_button( iv_button = 'F06' iv_text = 'Remove Auth'
                                   iv_icon = icon_delete iv_qinfo = 'Remove selected roles' ).
  go_falv->gui_status->add_button( iv_button = 'F07' iv_text = 'Check SoD'
                                   iv_icon = icon_check iv_qinfo = 'Check SoD conflicts' ).
  go_falv->gui_status->add_button( iv_button = 'F08' iv_text = 'Audit History'
                                   iv_icon = icon_information iv_qinfo = 'View audit history' ).

* FALV full-screen display delegates to SAPLZFALV and does not call
* RAISE_TOP_OF_PAGE automatically. Render the document explicitly so
* the summary remains visible above the grid while keeping the dynamic actions.
  DATA lo_top_doc TYPE REF TO cl_dd_document.
  CREATE OBJECT lo_top_doc.
  go_falv->show_top_of_page( ).
  EXPORT alv_form_html FROM abap_true TO MEMORY ID 'ALV_FORM_HTML'.
  go_falv->list_processing_events(
    i_event_name = 'TOP_OF_PAGE'
    i_dyndoc_id  = lo_top_doc ).
  EXPORT alv_form_html FROM abap_false TO MEMORY ID 'ALV_FORM_HTML'.
  lo_top_doc->display_document(
    EXPORTING
      reuse_control      = 'X'
      parent             = go_falv->top_of_page_container
    EXCEPTIONS
      html_display_error = 0
      OTHERS             = 0 ).
  go_falv->display( ).
ENDFORM.
*& Module USER_COMMAND_0100 INPUT
*&---------------------------------------------------------------------*

*&---------------------------------------------------------------------*
*& Form GET_DATA
*&---------------------------------------------------------------------*
FORM get_data.
  DATA lv_date_check TYPE dats.
  TYPES:
    BEGIN OF ty_user_base,
      bname TYPE usr02-bname,
      erdat TYPE xuerdat,
      trdat TYPE xuldate,
      ltime TYPE xultime,
      uflag TYPE xuuflag,
    END OF ty_user_base,
    BEGIN OF ty_contact,
      bname      TYPE usr02-bname,
      fname      TYPE ad_namtext,
      email      TYPE ad_smtpadr,
      department TYPE ad_dprtmnt,
    END OF ty_contact.
  DATA: lt_users    TYPE STANDARD TABLE OF ty_user_base WITH EMPTY KEY,
        lt_contacts TYPE STANDARD TABLE OF ty_contact WITH EMPTY KEY,
        ls_contact  TYPE ty_contact.

  CALL FUNCTION 'GET_SYSTEM_TIMEZONE'
    IMPORTING
      timezone = gv_timezone.

  lv_date_check = sy-datum - 30.
  CLEAR gt_alv.

  "This is a range report, so one database set read is more efficient than many buffer lookups.
  SELECT bname, erdat, trdat, ltime, uflag
    FROM usr02 BYPASSING BUFFER
    INTO TABLE @lt_users
    WHERE bname IN @s_bname
      AND trdat IN @s_trdat
      AND erdat IN @s_erdat
    ORDER BY bname.

  IF p_act IS INITIAL.
    DELETE lt_users WHERE uflag = 0.
  ENDIF.
  IF p_dact IS INITIAL.
    DELETE lt_users WHERE uflag NE 0.
  ENDIF.

  IF lt_users IS NOT INITIAL.
    "USR02 is deliberately kept out of this address join to preserve its table-buffer policy.
    SELECT b~bname,
           d~name_text AS fname,
           c~smtp_addr AS email,
           e~department AS department
      FROM usr21 AS b
      LEFT JOIN adr6 AS c
        ON c~persnumber = b~persnumber
       AND c~addrnumber = b~addrnumber
      LEFT JOIN adrp AS d
        ON d~persnumber = b~persnumber
      LEFT JOIN adcp AS e
        ON e~persnumber = b~persnumber
       AND e~addrnumber = b~addrnumber
      FOR ALL ENTRIES IN @lt_users
      WHERE b~bname = @lt_users-bname
      INTO TABLE @lt_contacts.
    SORT lt_contacts BY bname.
    DELETE ADJACENT DUPLICATES FROM lt_contacts COMPARING bname.
  ENDIF.

  LOOP AT lt_users INTO DATA(ls_user).
    CLEAR ls_contact.
    READ TABLE lt_contacts INTO ls_contact WITH KEY bname = ls_user-bname BINARY SEARCH.
    APPEND VALUE gty_alv(
      bname       = ls_user-bname
      erdat       = ls_user-erdat
      trdat       = ls_user-trdat
      ltime       = ls_user-ltime
      erdat_text  = COND #( WHEN ls_user-erdat IS INITIAL THEN ''
                            ELSE |{ ls_user-erdat+6(2) }.{ ls_user-erdat+4(2) }.{ ls_user-erdat+0(4) }| )
      trdat_text  = COND #( WHEN ls_user-trdat IS INITIAL THEN ''
                            ELSE |{ ls_user-trdat+6(2) }.{ ls_user-trdat+4(2) }.{ ls_user-trdat+0(4) }| )
      ltime_text  = COND #( WHEN ls_user-ltime IS INITIAL THEN ''
                            ELSE |{ ls_user-ltime+0(2) }:{ ls_user-ltime+2(2) }:{ ls_user-ltime+4(2) }| )
      uflag       = ls_user-uflag
      user_status = COND #( WHEN ls_user-uflag = 0 THEN 'Active' ELSE 'Inactive' )
      fname       = ls_contact-fname
      email       = ls_contact-email
      department  = ls_contact-department ) TO gt_alv.
  ENDLOOP.

  DATA ls_color TYPE lvc_s_scol.
  LOOP AT gt_alv REFERENCE INTO DATA(lr).
    IF lr->uflag = 0 AND lr->trdat LT lv_date_check.
      CLEAR ls_color.
      ls_color-fname = 'TRDAT'.
      ls_color-color-col = 6.
      APPEND ls_color TO lr->color.
      ls_color-fname = 'USER_STATUS'.
      APPEND ls_color TO lr->color.
      ls_color-fname = 'LTIME'.
      APPEND ls_color TO lr->color.
    ENDIF.
  ENDLOOP.

  PERFORM get_audit_overview.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form GET_AUDIT_OVERVIEW
*&---------------------------------------------------------------------*
FORM format_timestamp USING iv_timestamp TYPE timestampl
                      CHANGING cv_text TYPE char19.
  DATA: lv_date TYPE dats,
        lv_time TYPE tims,
        lv_zone TYPE timezone.

  CLEAR cv_text.
  IF iv_timestamp IS INITIAL.
    RETURN.
  ENDIF.

  lv_zone = gv_timezone.
  IF lv_zone IS INITIAL.
    lv_zone = 'UTC'.
  ENDIF.
  CONVERT TIME STAMP iv_timestamp TIME ZONE lv_zone
    INTO DATE lv_date TIME lv_time.
  IF sy-subrc = 0.
    cv_text = |{ lv_date+0(4) }-{ lv_date+4(2) }-{ lv_date+6(2) } { lv_time+0(2) }:{ lv_time+2(2) }:{ lv_time+4(2) }|.
  ENDIF.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form ACTION_TEXT
*&---------------------------------------------------------------------*
FORM action_text USING iv_action TYPE char20
                 CHANGING cv_text TYPE char40.
  CLEAR cv_text.
  CASE iv_action.
    WHEN 'APPROVE_REQ'.      cv_text = 'Request approved'.
    WHEN 'SOD_ROLE_RM'.      cv_text = 'SoD role removed'.
    WHEN 'SOD_CRIT_APPR'.    cv_text = 'SoD exception approved'.
    WHEN 'INA_CASE_CLOSE'.   cv_text = 'Inactivity case closed'.
    WHEN 'INA_THRESHOLD_CFG'. cv_text = 'Inactivity threshold updated'.
    WHEN 'INA_LOCK_BEGIN'.   cv_text = 'Inactivity lock started'.
    WHEN 'INA_LOCK_OK'.      cv_text = 'User locked by inactivity'.
    WHEN 'INA_LOCK_ERR'.     cv_text = 'Inactivity lock failed'.
    WHEN 'INA_LOCK_RECOVER'. cv_text = 'Inactivity lock recovered'.
    WHEN 'INA_EXT_LOCK'.     cv_text = 'Externally locked user'.
    WHEN 'INA_WARN_OK'.      cv_text = 'Inactivity warning sent'.
    WHEN 'INA_WARN_ERR'.     cv_text = 'Inactivity warning failed'.
    WHEN 'FF_GRANT_PENDING'. cv_text = 'Emergency access pending'.
    WHEN 'FF_GRANT_OK'.      cv_text = 'Emergency access granted'.
    WHEN 'FF_GRANT_ERR'.     cv_text = 'Emergency access failed'.
    WHEN 'FF_REVOKE_OK'.     cv_text = 'Emergency access revoked'.
    WHEN 'FF_REVOKE_ERR'.    cv_text = 'Emergency access revoke failed'.
    WHEN OTHERS.
      cv_text = iv_action.
      REPLACE ALL OCCURRENCES OF '_' IN cv_text WITH ' '.
  ENDCASE.
ENDFORM.

FORM get_audit_overview.
  DATA: lt_audit   TYPE STANDARD TABLE OF gty_audit WITH EMPTY KEY,
        lt_request TYPE STANDARD TABLE OF gty_request WITH EMPTY KEY,
        lv_audit_count   TYPE i,
        lv_request_count TYPE i,
        lv_pending_count TYPE i.

  SELECT log_id, target_user, action_type, performed_by, old_value,
         new_value, timestamp, source_module
    FROM ziam_aud_log2
    INTO TABLE @lt_audit
    WHERE target_user IN @s_bname.

  SELECT target_user, req_id, status, requested_by, created_by,
         approved_by, created_at, last_changed_at
    FROM ziam_lreq_hdr2
    INTO TABLE @lt_request
    WHERE target_user IN @s_bname.

  SORT lt_audit BY target_user timestamp DESCENDING.
  SORT lt_request BY target_user last_changed_at DESCENDING.

  LOOP AT gt_alv ASSIGNING FIELD-SYMBOL(<ls_user>).
    CLEAR: lv_audit_count, lv_request_count, lv_pending_count.
    CLEAR: <ls_user>-last_action, <ls_user>-last_changed_by,
           <ls_user>-last_changed_at, <ls_user>-audit_count,
           <ls_user>-last_req_id, <ls_user>-last_req_status,
           <ls_user>-last_req_by, <ls_user>-last_req_at,
           <ls_user>-approved_by, <ls_user>-last_req_changed,
           <ls_user>-pending_req_count.

    LOOP AT lt_audit INTO DATA(ls_audit)
         WHERE target_user = <ls_user>-bname.
      ADD 1 TO lv_audit_count.
      IF lv_audit_count = 1.
        PERFORM action_text USING ls_audit-action_type
                           CHANGING <ls_user>-last_action.
        <ls_user>-last_changed_by = ls_audit-performed_by.
        PERFORM format_timestamp USING ls_audit-timestamp
                                 CHANGING <ls_user>-last_changed_at.
      ENDIF.
    ENDLOOP.
    <ls_user>-audit_count = lv_audit_count.

    LOOP AT lt_request INTO DATA(ls_request)
         WHERE target_user = <ls_user>-bname.
      ADD 1 TO lv_request_count.
      IF lv_request_count = 1.
        <ls_user>-last_req_id      = ls_request-req_id.
        <ls_user>-last_req_status  = COND #( WHEN ls_request-status = '01' THEN 'Draft'
                                             WHEN ls_request-status = '02' THEN 'Submitted'
                                             WHEN ls_request-status = '03' THEN 'Approved'
                                             WHEN ls_request-status = '04' THEN 'Rejected'
                                             ELSE 'New' ).
        <ls_user>-last_req_by      = COND #( WHEN ls_request-requested_by IS NOT INITIAL
                                             THEN ls_request-requested_by
                                             ELSE ls_request-created_by ).
        PERFORM format_timestamp USING ls_request-created_at
                                 CHANGING <ls_user>-last_req_at.
        <ls_user>-approved_by      = ls_request-approved_by.
        PERFORM format_timestamp USING ls_request-last_changed_at
                                 CHANGING <ls_user>-last_req_changed.
      ENDIF.
      IF ls_request-status = '01' OR ls_request-status = '02'.
        ADD 1 TO lv_pending_count.
      ENDIF.
    ENDLOOP.
    <ls_user>-pending_req_count = lv_pending_count.
  ENDLOOP.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form SHOW_AUDIT
*&---------------------------------------------------------------------*
FORM show_audit.
  DATA: lr_users TYPE RANGE OF xubname,
        lt_audit_popup TYPE STANDARD TABLE OF gty_audit WITH EMPTY KEY,
        lv_valid TYPE c.

  go_grid->check_changed_data( IMPORTING e_valid = lv_valid ).
  LOOP AT gt_alv INTO DATA(ls_user) WHERE flag = 'X'.
    APPEND VALUE #( sign = 'I' option = 'EQ' low = ls_user-bname ) TO lr_users.
  ENDLOOP.

  IF lr_users IS INITIAL.
    MESSAGE s011(zmsg_iam07) DISPLAY LIKE 'W'.
    RETURN.
  ENDIF.

  SELECT log_id, target_user, action_type, performed_by, old_value,
         new_value, timestamp, source_module
    FROM ziam_aud_log2
    INTO TABLE @lt_audit_popup
    WHERE target_user IN @lr_users.

  IF lt_audit_popup IS INITIAL.
    MESSAGE s012(zmsg_iam07) DISPLAY LIKE 'W'.
    RETURN.
  ENDIF.

  LOOP AT lt_audit_popup ASSIGNING FIELD-SYMBOL(<ls_audit_popup>).
    PERFORM action_text USING <ls_audit_popup>-action_type
                       CHANGING <ls_audit_popup>-action_text.
    PERFORM format_timestamp USING <ls_audit_popup>-timestamp
                             CHANGING <ls_audit_popup>-timestamp_text.
  ENDLOOP.

  SORT lt_audit_popup BY target_user timestamp DESCENDING.

  DATA lo TYPE REF TO cl_salv_table.
  TRY.
      cl_salv_table=>factory(
        IMPORTING r_salv_table = lo
        CHANGING  t_table      = lt_audit_popup ).

      lo->set_screen_popup(
        start_column = 5 end_column = 170
        start_line = 2 end_line = 30 ).
      lo->get_display_settings( )->set_list_header( 'User Audit History' ).
      lo->get_columns( )->set_optimize( abap_true ).
      lo->get_columns( )->get_column( 'ACTION_TYPE' )->set_visible( abap_false ).
      lo->get_columns( )->get_column( 'TIMESTAMP' )->set_visible( abap_false ).
      lo->get_columns( )->get_column( 'LOG_ID' )->set_long_text( 'Audit Log ID' ).
      lo->get_columns( )->get_column( 'TARGET_USER' )->set_long_text( 'Target User' ).
      lo->get_columns( )->get_column( 'PERFORMED_BY' )->set_long_text( 'Changed By' ).
      lo->get_columns( )->get_column( 'OLD_VALUE' )->set_long_text( 'Previous Value' ).
      lo->get_columns( )->get_column( 'NEW_VALUE' )->set_long_text( 'New Value' ).
      lo->get_columns( )->get_column( 'SOURCE_MODULE' )->set_long_text( 'Source' ).
      lo->get_columns( )->get_column( 'ACTION_TEXT' )->set_long_text( 'Action' ).
      lo->get_columns( )->get_column( 'TIMESTAMP_TEXT' )->set_long_text( 'Changed At' ).
      lo->get_functions( )->set_all( abap_true ).
      lo->display( ).
    CATCH cx_salv_msg cx_salv_not_found cx_salv_wrong_call cx_salv_existing
          cx_salv_method_not_supported.
  ENDTRY.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form BUILD_FIELDCAT
*&---------------------------------------------------------------------*
FORM append_fieldcat USING iv_fieldname TYPE lvc_fname
                            iv_text      TYPE string
                            iv_outputlen TYPE i.
  DATA ls_fcat TYPE lvc_s_fcat.

  CLEAR ls_fcat.
  ls_fcat-fieldname = iv_fieldname.
  ls_fcat-coltext   = iv_text.
  ls_fcat-seltext   = iv_text.
  ls_fcat-scrtext_l = iv_text.
  ls_fcat-scrtext_m = iv_text.
  ls_fcat-scrtext_s = iv_text.
  ls_fcat-reptext   = iv_text.
  ls_fcat-tooltip   = iv_text.
  ls_fcat-outputlen = iv_outputlen.
  APPEND ls_fcat TO gt_fcat.
ENDFORM.

FORM build_fieldcat.
  CLEAR gt_fcat.

  PERFORM append_fieldcat USING 'FLAG'              'Select'              5.
  PERFORM append_fieldcat USING 'BNAME'             'User Name'           12.
  PERFORM append_fieldcat USING 'FNAME'             'Full Name'           30.
  PERFORM append_fieldcat USING 'ERDAT_TEXT'        'Creation Date'       12.
  PERFORM append_fieldcat USING 'TRDAT_TEXT'        'Last Logon Date'     15.
  PERFORM append_fieldcat USING 'LTIME_TEXT'        'Last Logon Time'     10.
  PERFORM append_fieldcat USING 'USER_STATUS'       'Status'              10.
  PERFORM append_fieldcat USING 'DEPARTMENT'        'Department'          20.
  PERFORM append_fieldcat USING 'EMAIL'             'Email'               30.
  PERFORM append_fieldcat USING 'LAST_ACTION'       'Last Action'          32.
  PERFORM append_fieldcat USING 'LAST_CHANGED_BY'   'Changed By'           12.
  PERFORM append_fieldcat USING 'LAST_CHANGED_AT'   'Changed At (Local)'   19.
  PERFORM append_fieldcat USING 'AUDIT_COUNT'       'Audit Events'         12.
  PERFORM append_fieldcat USING 'LAST_REQ_ID'       'Last Request'         20.
  PERFORM append_fieldcat USING 'LAST_REQ_STATUS'   'Request Status'       15.
  PERFORM append_fieldcat USING 'LAST_REQ_BY'       'Requested By'         12.
  PERFORM append_fieldcat USING 'LAST_REQ_AT'       'Request Created'      19.
  PERFORM append_fieldcat USING 'APPROVED_BY'       'Approved By'          12.
  PERFORM append_fieldcat USING 'LAST_REQ_CHANGED'  'Request Updated'     19.
  PERFORM append_fieldcat USING 'PENDING_REQ_COUNT' 'Pending Requests'     16.

  READ TABLE gt_fcat ASSIGNING FIELD-SYMBOL(<ls_flag>)
       WITH KEY fieldname = 'FLAG'.
  IF sy-subrc = 0.
    <ls_flag>-checkbox = abap_true.
    <ls_flag>-edit     = abap_true.
  ENDIF.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form SET_LAYOUT
*&---------------------------------------------------------------------*
FORM set_layout.
  CLEAR gs_layout.
  gs_layout-sel_mode   = 'A'.
  gs_layout-zebra      = 'X'.
  gs_layout-ctab_fname = 'COLOR'.
  gs_layout-cwidth_opt = space.
  PERFORM build_header_text.
  gs_layout-grid_title = gv_header_text.

  CLEAR gs_variant.
  gs_variant-report = sy-repid.
  gs_variant-handle = 'USER'.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form BUILD_HEADER_TEXT
*&---------------------------------------------------------------------*
FORM build_header_text.
  DATA: lv_total    TYPE i,
        lv_active   TYPE i,
        lv_inactive TYPE i,
        lv_pending   TYPE i,
        lv_audits    TYPE i.

  DESCRIBE TABLE gt_alv LINES lv_total.
  LOOP AT gt_alv INTO DATA(ls_user).
    IF ls_user-uflag = 0.
      ADD 1 TO lv_active.
    ELSE.
      ADD 1 TO lv_inactive.
    ENDIF.
    lv_pending = lv_pending + ls_user-pending_req_count.
    lv_audits  = lv_audits + ls_user-audit_count.
  ENDLOOP.

  gv_header_text = |IAM Users - Total: { lv_total } - Active: { lv_active } - Inactive: { lv_inactive } - Pending: { lv_pending } - Audit: { lv_audits }|.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form REFRESH_ALV
*&---------------------------------------------------------------------*
FORM refresh_alv.
  PERFORM build_header_text.
  go_grid->set_gridtitle( i_gridtitle = gv_header_text ).
  go_grid->refresh_table_display( ).
ENDFORM.

*&---------------------------------------------------------------------*
*& Form SET_TOOLBAR_EXCLUDE
*&---------------------------------------------------------------------*
FORM set_toolbar_exclude.
  CLEAR gt_exclude.
* Keep standard navigation, filtering, export, refresh and layout variants.
* Only exclude functions that would allow accidental table editing or
* duplicate the explicit business actions provided by this report.
  APPEND VALUE #( fcode = cl_gui_alv_grid=>mc_fc_loc_insert_row ) TO gt_exclude.
  APPEND VALUE #( fcode = cl_gui_alv_grid=>mc_fc_loc_delete_row ) TO gt_exclude.
  APPEND VALUE #( fcode = cl_gui_alv_grid=>mc_fc_loc_append_row ) TO gt_exclude.
  APPEND VALUE #( fcode = cl_gui_alv_grid=>mc_fc_loc_copy_row ) TO gt_exclude.
  APPEND VALUE #( fcode = cl_gui_alv_grid=>mc_fc_loc_cut ) TO gt_exclude.
  APPEND VALUE #( fcode = cl_gui_alv_grid=>mc_fc_loc_paste ) TO gt_exclude.
  APPEND VALUE #( fcode = cl_gui_alv_grid=>mc_fc_loc_undo ) TO gt_exclude.
* Keep standard sort/filter/find/export/refresh/layout functions visible.
  APPEND VALUE #( fcode = cl_gui_alv_grid=>mc_fc_select_all ) TO gt_exclude.
  APPEND VALUE #( fcode = cl_gui_alv_grid=>mc_fc_deselect_all ) TO gt_exclude.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form HANDLE_ALV_UCOMM
*&---------------------------------------------------------------------*
FORM handle_alv_ucomm USING p_ucomm TYPE sy-ucomm.
  CASE p_ucomm.
    WHEN 'ALL'.       PERFORM select_lines_all.
    WHEN 'DALL'.      PERFORM deselect_lines_all.
    WHEN 'LOCK'.      PERFORM lock_user.
    WHEN 'UNLOCK'.     PERFORM unlock_user.
    WHEN 'CHECK_AUTH'.  PERFORM check_auth.
    WHEN 'REMOVE_AUTH'. PERFORM remove_auth.
    WHEN 'CHECK_SOD'.    PERFORM check_sod.
    WHEN 'AUDIT'.        PERFORM show_audit.
  ENDCASE.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form SELECT_LINES_ALL / DESELECT_LINES_ALL
*&---------------------------------------------------------------------*
FORM select_lines_all.
  DATA lv TYPE c.
  go_grid->check_changed_data( IMPORTING e_valid = lv ).
  LOOP AT gt_alv REFERENCE INTO DATA(ls). ls->flag = 'X'. ENDLOOP.
  PERFORM refresh_alv.
ENDFORM.

FORM deselect_lines_all.
  DATA lv TYPE c.
  go_grid->check_changed_data( IMPORTING e_valid = lv ).
  LOOP AT gt_alv REFERENCE INTO DATA(ls). ls->flag = ''. ENDLOOP.
  PERFORM refresh_alv.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form LOCK_USER
*&---------------------------------------------------------------------*
FORM lock_user.
  DATA: lv_indx  TYPE i, lv_valid TYPE c.

  go_grid->check_changed_data( IMPORTING e_valid = lv_valid ).
  REFRESH gt_tab.

  LOOP AT gt_alv INTO DATA(wa) WHERE flag = 'X'.
    ADD 1 TO lv_indx.
    CALL FUNCTION 'BAPI_USER_LOCK'
      EXPORTING
        username = wa-bname
      TABLES
        return   = gt_return.
    LOOP AT gt_return INTO DATA(r).
      gs_tab-lineno = lv_indx. gs_tab-msgid = r-id. gs_tab-msgno = r-number.
      gs_tab-msgty = r-type. gs_tab-msgv1 = r-message_v1.
      gs_tab-msgv2 = r-message_v2. gs_tab-msgv3 = r-message_v3.
      APPEND gs_tab TO gt_tab.
    ENDLOOP.
    REFRESH gt_return.
  ENDLOOP.

  IF lv_indx = 0.
    MESSAGE s011(zmsg_iam07) DISPLAY LIKE 'W'.
    RETURN.
  ENDIF.

  CALL FUNCTION 'BAPI_TRANSACTION_COMMIT' EXPORTING wait = 'X'.

  IF gt_tab IS NOT INITIAL.
    CALL FUNCTION 'C14Z_MESSAGES_SHOW_AS_POPUP'
      TABLES
        i_message_tab = gt_tab.
  ENDIF.
  REFRESH gt_tab.

  PERFORM get_data.
  PERFORM refresh_alv.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form UNLOCK_USER
*&---------------------------------------------------------------------*
FORM unlock_user.
  DATA: lv_indx  TYPE i, lv_valid TYPE c.

  go_grid->check_changed_data( IMPORTING e_valid = lv_valid ).
  REFRESH gt_tab.

  LOOP AT gt_alv INTO DATA(wa) WHERE flag = 'X'.
    ADD 1 TO lv_indx.
    CALL FUNCTION 'BAPI_USER_UNLOCK'
      EXPORTING
        username = wa-bname
      TABLES
        return   = gt_return.
    LOOP AT gt_return INTO DATA(r).
      gs_tab-lineno = lv_indx. gs_tab-msgid = r-id. gs_tab-msgno = r-number.
      gs_tab-msgty = r-type. gs_tab-msgv1 = r-message_v1.
      gs_tab-msgv2 = r-message_v2. gs_tab-msgv3 = r-message_v3.
      APPEND gs_tab TO gt_tab.
    ENDLOOP.
    REFRESH gt_return.
  ENDLOOP.

  IF lv_indx = 0.
    MESSAGE s011(zmsg_iam07) DISPLAY LIKE 'W'.
    RETURN.
  ENDIF.

  CALL FUNCTION 'BAPI_TRANSACTION_COMMIT' EXPORTING wait = 'X'.

  IF gt_tab IS NOT INITIAL.
    CALL FUNCTION 'C14Z_MESSAGES_SHOW_AS_POPUP'
      TABLES
        i_message_tab = gt_tab.
  ENDIF.
  REFRESH gt_tab.

  PERFORM get_data.
  PERFORM refresh_alv.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form CHECK_AUTH
*&---------------------------------------------------------------------*
FORM check_auth.
  DATA: lv_valid TYPE c,
        lt_agr   TYPE TABLE OF bapiagr,
        lt_ret   TYPE TABLE OF bapiret2.

  go_grid->check_changed_data( IMPORTING e_valid = lv_valid ).
  CLEAR gt_roles.

  LOOP AT gt_alv INTO DATA(wa) WHERE flag = 'X'.
    REFRESH: lt_agr, lt_ret.
    CALL FUNCTION 'BAPI_USER_GET_DETAIL'
      EXPORTING
        username       = wa-bname
      TABLES
        activitygroups = lt_agr
        return         = lt_ret.
    LOOP AT lt_agr INTO DATA(ag).
      APPEND VALUE gty_role(
        bname    = wa-bname
        agr_name = ag-agr_name
        from_dat = ag-from_dat
        to_dat   = ag-to_dat ) TO gt_roles.
    ENDLOOP.
  ENDLOOP.

  IF gt_roles IS INITIAL.
    MESSAGE s015(zmsg_iam07).
    RETURN.
  ENDIF.

  DATA lo TYPE REF TO cl_salv_table.
  TRY.
      cl_salv_table=>factory(
        IMPORTING r_salv_table = lo
        CHANGING  t_table      = gt_roles ).

      lo->set_screen_popup(
        start_column = 10 end_column = 120
        start_line = 3 end_line = 22 ).

      lo->get_display_settings( )->set_list_header( 'User Role Assignments' ).
      lo->get_columns( )->set_optimize( abap_true ).
      lo->get_functions( )->set_all( abap_true ).

      lo->display( ).
    CATCH cx_salv_msg cx_salv_not_found cx_salv_wrong_call cx_salv_existing
          cx_salv_method_not_supported.
  ENDTRY.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form REMOVE_AUTH
*&---------------------------------------------------------------------*
FORM remove_auth.
  DATA: lv_valid TYPE c,
        lt_agr   TYPE TABLE OF bapiagr,
        lt_ret   TYPE TABLE OF bapiret2,
        lt_popup TYPE TABLE OF gty_role,
        lt_fcat  TYPE slis_t_fieldcat_alv,
        ls_fcat  TYPE slis_fieldcat_alv,
        lv_exit  TYPE c.

  go_grid->check_changed_data( IMPORTING e_valid = lv_valid ).
  CLEAR lt_popup.

* Collect roles for selected users
  LOOP AT gt_alv INTO DATA(wa) WHERE flag = 'X'.
    REFRESH: lt_agr, lt_ret.
    CALL FUNCTION 'BAPI_USER_GET_DETAIL'
      EXPORTING
        username       = wa-bname
      TABLES
        activitygroups = lt_agr
        return         = lt_ret.
    LOOP AT lt_agr INTO DATA(ag).
      APPEND VALUE gty_role(
        bname    = wa-bname
        agr_name = ag-agr_name
        from_dat = ag-from_dat
        to_dat   = ag-to_dat ) TO lt_popup.
    ENDLOOP.
  ENDLOOP.

  IF lt_popup IS INITIAL.
    MESSAGE s015(zmsg_iam07).
    RETURN.
  ENDIF.

* Build field catalog for popup ALV
  CLEAR lt_fcat.
  CLEAR ls_fcat. ls_fcat-fieldname = 'FLAG'. ls_fcat-seltext_l = 'Select'.
  ls_fcat-checkbox = 'X'. ls_fcat-edit = 'X'. ls_fcat-outputlen = 6. APPEND ls_fcat TO lt_fcat.
  CLEAR ls_fcat. ls_fcat-fieldname = 'BNAME'. ls_fcat-seltext_l = 'User Name'.
  ls_fcat-outputlen = 12. APPEND ls_fcat TO lt_fcat.
  CLEAR ls_fcat. ls_fcat-fieldname = 'AGR_NAME'. ls_fcat-seltext_l = 'Role'.
  ls_fcat-outputlen = 40. APPEND ls_fcat TO lt_fcat.
  CLEAR ls_fcat. ls_fcat-fieldname = 'FROM_DAT'. ls_fcat-seltext_l = 'Valid From'.
  ls_fcat-outputlen = 12. APPEND ls_fcat TO lt_fcat.
  CLEAR ls_fcat. ls_fcat-fieldname = 'TO_DAT'. ls_fcat-seltext_l = 'Valid To'.
  ls_fcat-outputlen = 12. APPEND ls_fcat TO lt_fcat.

* Display popup with checkbox selection
  CALL FUNCTION 'REUSE_ALV_POPUP_TO_SELECT'
    EXPORTING
      i_title              = 'Select Roles to Remove'
      i_selection          = 'X'
      i_zebra              = 'X'
      i_checkbox_fieldname = 'FLAG'
      i_tabname            = 'LT_POPUP'
      it_fieldcat          = lt_fcat
    IMPORTING
      e_exit               = lv_exit
    TABLES
      t_outtab             = lt_popup
    EXCEPTIONS
      program_error        = 1
      OTHERS               = 2.

  IF sy-subrc <> 0 OR lv_exit = 'X'.
    RETURN.
  ENDIF.

* Get selected roles (flag = 'X')
  DATA lt_sel TYPE TABLE OF gty_role.
  LOOP AT lt_popup INTO DATA(rp) WHERE flag = 'X'.
    APPEND rp TO lt_sel.
  ENDLOOP.

  IF lt_sel IS INITIAL.
    MESSAGE s016(zmsg_iam07) DISPLAY LIKE 'W'.
    RETURN.
  ENDIF.

* Confirm removal
  DATA lv_answer TYPE c.
  DATA(lv_cnt) = lines( lt_sel ).
  DATA lv_msg TYPE string.
  MESSAGE ID 'ZMSG_IAM07' TYPE 'S' NUMBER '019'
    WITH lv_cnt INTO lv_msg.
  CALL FUNCTION 'POPUP_TO_CONFIRM'
    EXPORTING
      titlebar              = 'Confirm Role Removal'
      text_question         = lv_msg
      text_button_1         = 'Yes'
      text_button_2         = 'No'
      default_button        = '2'
      display_cancel_button = ' '
    IMPORTING
      answer                = lv_answer.

  IF lv_answer <> '1'. RETURN. ENDIF.

* Process removal: for each user, get current roles, remove selected, reassign
  DATA: lt_ulist TYPE TABLE OF usr02-bname,
        lv_err   TYPE abap_bool.
  LOOP AT lt_sel INTO DATA(sl2).
    APPEND sl2-bname TO lt_ulist.
  ENDLOOP.
  SORT lt_ulist. DELETE ADJACENT DUPLICATES FROM lt_ulist.

  LOOP AT lt_ulist INTO DATA(bn).
    REFRESH: lt_agr, lt_ret.
    CALL FUNCTION 'BAPI_USER_GET_DETAIL'
      EXPORTING
        username       = bn
      TABLES
        activitygroups = lt_agr
        return         = lt_ret.
    LOOP AT lt_sel INTO DATA(rl) WHERE bname = bn.
      DELETE lt_agr WHERE agr_name = rl-agr_name.
    ENDLOOP.
    REFRESH lt_ret.
    CALL FUNCTION 'BAPI_USER_ACTGROUPS_ASSIGN'
      EXPORTING
        username       = bn
      TABLES
        activitygroups = lt_agr
        return         = lt_ret.
    LOOP AT lt_ret INTO DATA(rt) WHERE type = 'E' OR type = 'A'.
      lv_err = abap_true.
    ENDLOOP.
  ENDLOOP.

  IF lv_err = abap_false.
    CALL FUNCTION 'BAPI_TRANSACTION_COMMIT' EXPORTING wait = 'X'.
    MESSAGE s017(zmsg_iam07).
  ELSE.
    CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.
    MESSAGE s018(zmsg_iam07) DISPLAY LIKE 'E'.
  ENDIF.
ENDFORM.

