*&---------------------------------------------------------------------*
*& Report ZPG_RUSERS_01
*& User Status & Authorization Management
*&---------------------------------------------------------------------*
REPORT  .

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
    uflag       TYPE xuuflag,
    user_status TYPE char10,
    department  TYPE ad_dprtmnt,
    email       TYPE ad_smtpadr,
    color       TYPE lvc_t_scol,
  END OF gty_alv.

TYPES:
  BEGIN OF gty_role,
    flag     TYPE c,
    bname    TYPE usr02-bname,
    agr_name TYPE agr_name,
    from_dat TYPE dats,
    to_dat   TYPE dats,
  END OF gty_role.

DATA: gt_alv   TYPE TABLE OF gty_alv,
      gt_roles TYPE TABLE OF gty_role.

DATA: go_dock TYPE REF TO cl_gui_docking_container,
      go_grid TYPE REF TO cl_gui_alv_grid.

DATA: gt_fcat    TYPE lvc_t_fcat,
      gs_layout  TYPE lvc_s_layo,
      gt_exclude TYPE ui_functions,
      gs_variant TYPE disvariant,
      gv_header_text TYPE char70.

DATA: gt_return TYPE TABLE OF bapiret2,
      gt_tab    TYPE esp1_message_tab_type,
      gs_tab    TYPE esp1_message_wa_type.

DATA: gv_ok_code TYPE sy-ucomm.
INCLUDE zpg_iam_rusers_sod_i01.

CLASS lcl_alv_events DEFINITION.
  PUBLIC SECTION.
    METHODS on_toolbar FOR EVENT toolbar OF cl_gui_alv_grid
      IMPORTING e_object e_interactive.
    METHODS on_user_command FOR EVENT user_command OF cl_gui_alv_grid
      IMPORTING e_ucomm.
ENDCLASS.

CLASS lcl_alv_events IMPLEMENTATION.
  METHOD on_toolbar.
    DATA ls_button TYPE stb_button.
    "Keep the standard ALV toolbar (sort, filter, find, export, refresh and
    "layout variants).  Business actions are appended after the standard
    "functions so the screen remains familiar to SAP GUI users.
    CLEAR ls_button. ls_button-butn_type = 3.
    APPEND ls_button TO e_object->mt_toolbar.
    CLEAR ls_button. ls_button-function = 'ALL'. ls_button-icon = icon_select_all.
    ls_button-quickinfo = 'Select All'. ls_button-text = 'Select All'.
    APPEND ls_button TO e_object->mt_toolbar.
    CLEAR ls_button. ls_button-function = 'DALL'. ls_button-icon = icon_deselect_all.
    ls_button-quickinfo = 'Deselect All'. ls_button-text = 'Deselect All'.
    APPEND ls_button TO e_object->mt_toolbar.
    CLEAR ls_button. ls_button-butn_type = 3.
    APPEND ls_button TO e_object->mt_toolbar.
    CLEAR ls_button. ls_button-function = 'LOCK'. ls_button-icon = icon_locked.
    ls_button-quickinfo = 'Lock User'. ls_button-text = 'Lock'.
    APPEND ls_button TO e_object->mt_toolbar.
    CLEAR ls_button. ls_button-function = 'UNLOCK'. ls_button-icon = icon_unlocked.
    ls_button-quickinfo = 'Unlock User'. ls_button-text = 'Unlock'.
    APPEND ls_button TO e_object->mt_toolbar.
    CLEAR ls_button. ls_button-butn_type = 3.
    APPEND ls_button TO e_object->mt_toolbar.
    CLEAR ls_button. ls_button-function = 'CHECK_AUTH'. ls_button-icon = icon_check.
    ls_button-quickinfo = 'Check Roles'. ls_button-text = 'Check Auth'.
    APPEND ls_button TO e_object->mt_toolbar.
    CLEAR ls_button. ls_button-function = 'REMOVE_AUTH'. ls_button-icon = icon_delete.
    ls_button-quickinfo = 'Remove Roles'. ls_button-text = 'Remove Auth'.
    APPEND ls_button TO e_object->mt_toolbar.
    CLEAR ls_button. ls_button-function = 'CHECK_SOD'. ls_button-icon = icon_check.
    ls_button-quickinfo = 'Check segregation-of-duties conflicts'. ls_button-text = 'Check SoD'.
    APPEND ls_button TO e_object->mt_toolbar.
  ENDMETHOD.
  METHOD on_user_command.
    PERFORM handle_alv_ucomm USING e_ucomm.
  ENDMETHOD.
ENDCLASS.

* lcl_role_events removed - Remove Auth now uses REUSE_ALV_POPUP_TO_SELECT

DATA go_alv_handler TYPE REF TO lcl_alv_events.

START-OF-SELECTION.
  PERFORM get_data.
  IF gt_alv IS NOT INITIAL.
    CALL SCREEN 0100.
  ELSE.
    MESSAGE i012(zmsg_iam07) DISPLAY LIKE 'E'.
  ENDIF.

*&---------------------------------------------------------------------*
*& Module STATUS_0100 OUTPUT
*&---------------------------------------------------------------------*
MODULE status_0100 OUTPUT.
  SET PF-STATUS 'STANDARD_FULLSCREEN' OF PROGRAM 'SAPLSLVC_FULLSCREEN'.
ENDMODULE.

*&---------------------------------------------------------------------*
*& Module INIT_ALV_0100 OUTPUT
*&---------------------------------------------------------------------*
MODULE init_alv_0100 OUTPUT.
  IF go_dock IS INITIAL.
    CREATE OBJECT go_dock
      EXPORTING
        repid = sy-repid
        dynnr = '0100'
        side  = cl_gui_docking_container=>dock_at_top
        ratio = 95.

    CREATE OBJECT go_grid
      EXPORTING
        i_parent = go_dock.

    PERFORM build_fieldcat.
    PERFORM set_layout.
    PERFORM set_toolbar_exclude.

    CREATE OBJECT go_alv_handler.
    SET HANDLER go_alv_handler->on_toolbar FOR go_grid.
    SET HANDLER go_alv_handler->on_user_command FOR go_grid.

    go_grid->set_table_for_first_display(
      EXPORTING
        i_save               = 'A'
        is_variant           = gs_variant
        is_layout            = gs_layout
        it_toolbar_excluding = gt_exclude
      CHANGING
        it_outtab       = gt_alv
        it_fieldcatalog = gt_fcat ).
  ELSE.
    PERFORM refresh_alv.
  ENDIF.
ENDMODULE.

*&---------------------------------------------------------------------*
*& Module USER_COMMAND_0100 INPUT
*&---------------------------------------------------------------------*
MODULE user_command_0100 INPUT.
  gv_ok_code = sy-ucomm.
  CLEAR sy-ucomm.
  CASE gv_ok_code.
    WHEN 'BACK' OR '&F03'.
      LEAVE TO SCREEN 0.
    WHEN 'EXIT' OR '&F15'.
      LEAVE PROGRAM.
    WHEN 'CANCEL' OR '&F12'.
      LEAVE PROGRAM.
  ENDCASE.
ENDMODULE.

*&---------------------------------------------------------------------*
*& Form GET_DATA
*&---------------------------------------------------------------------*
FORM get_data.
  DATA: lv_date_check TYPE dats,
         lv_sys_tzone  TYPE timezone.
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
      timezone = lv_sys_tzone.

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
ENDFORM.

*&---------------------------------------------------------------------*
*& Form BUILD_FIELDCAT
*&---------------------------------------------------------------------*
FORM build_fieldcat.
  DATA ls TYPE lvc_s_fcat.
  CLEAR gt_fcat.

  CLEAR ls. ls-fieldname = 'FLAG'. ls-coltext = 'Select'.
  ls-checkbox = 'X'. ls-edit = 'X'. ls-outputlen = 5. APPEND ls TO gt_fcat.

  CLEAR ls. ls-fieldname = 'BNAME'. ls-coltext = 'User Name'.
  ls-outputlen = 12. APPEND ls TO gt_fcat.

  CLEAR ls. ls-fieldname = 'FNAME'. ls-coltext = 'Full Name'.
  ls-outputlen = 30. APPEND ls TO gt_fcat.

  CLEAR ls. ls-fieldname = 'ERDAT'. ls-coltext = 'Creation Date'.
  ls-outputlen = 12. APPEND ls TO gt_fcat.

  CLEAR ls. ls-fieldname = 'TRDAT'. ls-coltext = 'Last Logon Date'.
  ls-outputlen = 15. APPEND ls TO gt_fcat.

  CLEAR ls. ls-fieldname = 'LTIME'. ls-coltext = 'Last Logon Time'.
  ls-outputlen = 10. APPEND ls TO gt_fcat.

  CLEAR ls. ls-fieldname = 'USER_STATUS'. ls-coltext = 'Status'.
  ls-outputlen = 10. APPEND ls TO gt_fcat.

  CLEAR ls. ls-fieldname = 'DEPARTMENT'. ls-coltext = 'Department'.
  ls-outputlen = 20. APPEND ls TO gt_fcat.

  CLEAR ls. ls-fieldname = 'EMAIL'. ls-coltext = 'Email'.
  ls-outputlen = 30. APPEND ls TO gt_fcat.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form SET_LAYOUT
*&---------------------------------------------------------------------*
FORM set_layout.
  CLEAR gs_layout.
  gs_layout-sel_mode   = 'A'.
  gs_layout-zebra      = 'X'.
  gs_layout-ctab_fname = 'COLOR'.
  gs_layout-cwidth_opt = 'X'.
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
        lv_inactive TYPE i.

  DESCRIBE TABLE gt_alv LINES lv_total.
  LOOP AT gt_alv INTO DATA(ls_user).
    IF ls_user-uflag = 0.
      ADD 1 TO lv_active.
    ELSE.
      ADD 1 TO lv_inactive.
    ENDIF.
  ENDLOOP.

  gv_header_text = |IAM User Administration | Total: { lv_total } | Active: { lv_active } | Inactive: { lv_inactive }|.
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
  APPEND cl_gui_alv_grid=>mc_fc_loc_insert_row TO gt_exclude.
  APPEND cl_gui_alv_grid=>mc_fc_loc_delete_row TO gt_exclude.
  APPEND cl_gui_alv_grid=>mc_fc_loc_append_row TO gt_exclude.
  APPEND cl_gui_alv_grid=>mc_fc_loc_copy_row   TO gt_exclude.
  APPEND cl_gui_alv_grid=>mc_fc_loc_cut   TO gt_exclude.
  APPEND cl_gui_alv_grid=>mc_fc_loc_paste TO gt_exclude.
  APPEND cl_gui_alv_grid=>mc_fc_loc_undo  TO gt_exclude.
* Keep standard sort/filter/find/export/refresh/layout functions visible.
  APPEND cl_gui_alv_grid=>mc_fc_select_all   TO gt_exclude.
  APPEND cl_gui_alv_grid=>mc_fc_deselect_all TO gt_exclude.
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
