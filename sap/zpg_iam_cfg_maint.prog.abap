*&---------------------------------------------------------------------*
*& Report ZPG_IAM_CFG_MAINT
*& Interactive Editable ALV for ZIAM_FF_ROLE & ZIAM_SOD_RULE
*&---------------------------------------------------------------------*
REPORT zpg_iam_cfg_maint.

TABLES: ziam_ff_role, ziam_sod_rule.

SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-001.
  PARAMETERS: rb_ff  RADIOBUTTON GROUP g1 DEFAULT 'X',
              rb_sod RADIOBUTTON GROUP g1.
SELECTION-SCREEN END OF BLOCK b1.

DATA: gt_ff       TYPE STANDARD TABLE OF ziam_ff_role WITH DEFAULT KEY,
      gt_ff_orig  TYPE STANDARD TABLE OF ziam_ff_role WITH DEFAULT KEY,
      gt_sod      TYPE STANDARD TABLE OF ziam_sod_rule WITH DEFAULT KEY,
      gt_sod_orig TYPE STANDARD TABLE OF ziam_sod_rule WITH DEFAULT KEY.

DATA: gt_fcat TYPE lvc_t_fcat,
      gs_layo TYPE lvc_s_layo.

DATA: go_grid TYPE REF TO cl_gui_alv_grid.

*&---------------------------------------------------------------------*
*& Local class: Event Handler for OO ALV
*&---------------------------------------------------------------------*
CLASS lcl_event_handler DEFINITION.
  PUBLIC SECTION.
    CLASS-METHODS:
      on_toolbar FOR EVENT toolbar OF cl_gui_alv_grid
        IMPORTING e_object,
      on_user_command FOR EVENT user_command OF cl_gui_alv_grid
        IMPORTING e_ucomm,
      on_data_changed FOR EVENT data_changed OF cl_gui_alv_grid
        IMPORTING er_data_changed.
ENDCLASS.

CLASS lcl_event_handler IMPLEMENTATION.
  METHOD on_toolbar.
    DATA ls_toolbar TYPE stb_button.
    " Add Save button to ALV toolbar
    ls_toolbar-butn_type = 3. " Separator
    APPEND ls_toolbar TO e_object->mt_toolbar.

    CLEAR ls_toolbar.
    ls_toolbar-function  = 'SAVE_DATA'.
    ls_toolbar-icon      = '@2L@'. " ICON_SYSTEM_SAVE
    ls_toolbar-quickinfo = 'Save Data'.
    ls_toolbar-butn_type = 0.
    ls_toolbar-text      = 'Save'.
    APPEND ls_toolbar TO e_object->mt_toolbar.
  ENDMETHOD.

  METHOD on_user_command.
    IF go_grid IS BOUND.
      go_grid->check_changed_data( ).
    ENDIF.

    CASE e_ucomm.
      WHEN 'SAVE_DATA'.
        IF rb_ff = 'X'.
          PERFORM save_ff_roles.
        ELSE.
          PERFORM save_sod_rules.
        ENDIF.
    ENDCASE.
  ENDMETHOD.

  METHOD on_data_changed.
    DATA: ls_ins TYPE lvc_s_moce,
          lv_uname TYPE sy-uname,
          lv_ts_char TYPE char20.

    lv_uname = sy-uname.

    " Format current timestamp (must be raw numeric for internal conversion)
    DATA lv_ts TYPE timestamp.
    GET TIME STAMP FIELD lv_ts.
    lv_ts_char = lv_ts.

    LOOP AT er_data_changed->mt_inserted_rows INTO ls_ins.
      IF rb_ff = 'X'.
        " Auto-fill FF Owner User
        er_data_changed->modify_cell( i_row_id = ls_ins-row_id i_fieldname = 'OWNER' i_value = lv_uname ).
        er_data_changed->modify_cell( i_row_id = ls_ins-row_id i_fieldname = 'CHANGED_BY' i_value = lv_uname ).
        er_data_changed->modify_cell( i_row_id = ls_ins-row_id i_fieldname = 'CHANGED_AT' i_value = lv_ts_char ).
      ELSE.
        " Not needed for SOD as it doesn't have these audit fields on screen, but if it did, we'd add it here.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.



START-OF-SELECTION.
  IF rb_ff = 'X'.
    PERFORM maintain_ff_roles.
  ELSE.
    PERFORM maintain_sod_rules.
  ENDIF.

*&---------------------------------------------------------------------*
FORM maintain_ff_roles.
  "The maintenance view deliberately reads the complete client configuration.
  SELECT client, agr_name, owner, backup_owner, max_hours,
         sod_check, exclusive_ff, is_active, changed_by, changed_at,
         local_last_changed_at
    FROM ziam_ff_role
    INTO CORRESPONDING FIELDS OF TABLE @gt_ff.
  gt_ff_orig = gt_ff.
  PERFORM build_fcat_ff.
  PERFORM display_alv USING gt_ff.
ENDFORM.

*&---------------------------------------------------------------------*
FORM maintain_sod_rules.
  "The maintenance view deliberately reads the complete client configuration.
  SELECT client, rule_id, rule_name,
         auth_obj_1, auth_field_1, auth_value_1,
         auth_obj_2, auth_field_2, auth_value_2,
         risk_level, rule_type, conflict_role1, conflict_role2,
         suggested_action
    FROM ziam_sod_rule
    INTO CORRESPONDING FIELDS OF TABLE @gt_sod.
  gt_sod_orig = gt_sod.
  PERFORM build_fcat_sod.
  PERFORM display_alv USING gt_sod.
ENDFORM.

*&---------------------------------------------------------------------*
FORM display_alv USING pt_outtab TYPE STANDARD TABLE.
  " Generate dummy list screen so we can attach ALV to it
  WRITE: / ''.

  IF go_grid IS INITIAL.
    CREATE OBJECT go_grid
      EXPORTING
        i_parent = cl_gui_container=>screen0.

    SET HANDLER lcl_event_handler=>on_toolbar FOR go_grid.
    SET HANDLER lcl_event_handler=>on_user_command FOR go_grid.
    SET HANDLER lcl_event_handler=>on_data_changed FOR go_grid.

    go_grid->register_edit_event( i_event_id = cl_gui_alv_grid=>mc_evt_enter ).
    go_grid->register_edit_event( i_event_id = cl_gui_alv_grid=>mc_evt_modified ).
  ENDIF.

  CLEAR gs_layo.
  gs_layo-edit       = 'X'.
  gs_layo-zebra      = 'X'.
  gs_layo-cwidth_opt = 'X'.

  go_grid->set_table_for_first_display(
    EXPORTING
      is_layout       = gs_layo
    CHANGING
      it_outtab       = pt_outtab
      it_fieldcatalog = gt_fcat
    EXCEPTIONS
      OTHERS          = 1 ).

  " Refresh display if ALV was already created
  go_grid->refresh_table_display( ).
ENDFORM.

*&---------------------------------------------------------------------*
FORM build_fcat_ff.
  DATA ls TYPE lvc_s_fcat.
  REFRESH gt_fcat.

  CLEAR ls.
  ls-fieldname = 'AGR_NAME'. ls-coltext = 'Firefighter Role Name'.
  ls-scrtext_l = 'Firefighter Role Name'. ls-scrtext_m = 'FF Role Name'. ls-scrtext_s = 'FF Role'.
  ls-edit = 'X'. ls-key = 'X'.
  ls-ref_table = 'AGR_DEFINE'. ls-ref_field = 'AGR_NAME'. ls-f4availabl = 'X'.
  APPEND ls TO gt_fcat.

  CLEAR ls.
  ls-fieldname = 'OWNER'. ls-coltext = 'FF Owner User'.
  ls-scrtext_l = 'FF Owner User'. ls-scrtext_m = 'FF Owner'. ls-scrtext_s = 'Owner'.
  ls-edit = 'X'.
  ls-ref_table = 'USR02'. ls-ref_field = 'BNAME'. ls-f4availabl = 'X'.
  APPEND ls TO gt_fcat.

  CLEAR ls.
  ls-fieldname = 'BACKUP_OWNER'. ls-coltext = 'Backup Owner User'.
  ls-scrtext_l = 'Backup Owner User'. ls-scrtext_m = 'Backup Owner'. ls-scrtext_s = 'Backup'.
  ls-edit = 'X'.
  ls-ref_table = 'USR02'. ls-ref_field = 'BNAME'. ls-f4availabl = 'X'.
  APPEND ls TO gt_fcat.

  CLEAR ls.
  ls-fieldname = 'MAX_HOURS'. ls-coltext = 'Max Hours (1-24)'.
  ls-scrtext_l = 'Max Hours Allowed'. ls-scrtext_m = 'Max Hours'. ls-scrtext_s = 'MaxHrs'.
  ls-edit = 'X'. ls-outputlen = 12.
  APPEND ls TO gt_fcat.

  CLEAR ls.
  ls-fieldname = 'SOD_CHECK'. ls-coltext = 'SoD Check'.
  ls-scrtext_l = 'Check SoD Conflicts'. ls-scrtext_m = 'SoD Check'. ls-scrtext_s = 'SoD'.
  ls-edit = 'X'. ls-checkbox = 'X'.
  APPEND ls TO gt_fcat.

  CLEAR ls.
  ls-fieldname = 'EXCLUSIVE_FF'. ls-coltext = 'Exclusive FF'.
  ls-scrtext_l = 'Exclusive Firefighter'. ls-scrtext_m = 'Exclusive FF'. ls-scrtext_s = 'Excl'.
  ls-edit = 'X'. ls-checkbox = 'X'.
  APPEND ls TO gt_fcat.

  CLEAR ls.
  ls-fieldname = 'IS_ACTIVE'. ls-coltext = 'Active'.
  ls-scrtext_l = 'Active Status'. ls-scrtext_m = 'Active'. ls-scrtext_s = 'Act'.
  ls-edit = 'X'. ls-checkbox = 'X'.
  APPEND ls TO gt_fcat.

  CLEAR ls.
  ls-fieldname = 'CHANGED_BY'. ls-coltext = 'Changed By'.
  ls-scrtext_l = 'Last Changed By'. ls-scrtext_m = 'Changed By'. ls-scrtext_s = 'ChgBy'.
  ls-edit = ' '.
  APPEND ls TO gt_fcat.

  CLEAR ls.
  ls-fieldname = 'CHANGED_AT'. ls-coltext = 'Changed Timestamp'.
  ls-scrtext_l = 'Last Changed At'. ls-scrtext_m = 'Changed At'. ls-scrtext_s = 'ChgAt'.
  ls-edit = ' '.
  APPEND ls TO gt_fcat.
ENDFORM.

*&---------------------------------------------------------------------*
FORM build_fcat_sod.
  DATA ls TYPE lvc_s_fcat.
  REFRESH gt_fcat.

  CLEAR ls.
  ls-fieldname = 'RULE_ID'. ls-coltext = 'SoD Rule ID'.
  ls-scrtext_l = 'SoD Rule ID'. ls-scrtext_m = 'Rule ID'. ls-scrtext_s = 'RuleID'.
  ls-edit = 'X'. ls-key = 'X'.
  APPEND ls TO gt_fcat.

  CLEAR ls.
  ls-fieldname = 'RULE_NAME'. ls-coltext = 'Rule Description'.
  ls-scrtext_l = 'SoD Rule Description'. ls-scrtext_m = 'Rule Name'. ls-scrtext_s = 'Name'.
  ls-edit = 'X'. ls-outputlen = 40.
  APPEND ls TO gt_fcat.

  CLEAR ls.
  ls-fieldname = 'CONFLICT_ROLE1'. ls-coltext = 'Conflict Role 1'.
  ls-scrtext_l = 'First Conflicting Role'. ls-scrtext_m = 'Conflict Role 1'. ls-scrtext_s = 'Role1'.
  ls-edit = 'X'.
  ls-ref_table = 'AGR_DEFINE'. ls-ref_field = 'AGR_NAME'. ls-f4availabl = 'X'.
  APPEND ls TO gt_fcat.

  CLEAR ls.
  ls-fieldname = 'CONFLICT_ROLE2'. ls-coltext = 'Conflict Role 2'.
  ls-scrtext_l = 'Second Conflicting Role'. ls-scrtext_m = 'Conflict Role 2'. ls-scrtext_s = 'Role2'.
  ls-edit = 'X'.
  ls-ref_table = 'AGR_DEFINE'. ls-ref_field = 'AGR_NAME'. ls-f4availabl = 'X'.
  APPEND ls TO gt_fcat.

  CLEAR ls.
  ls-fieldname = 'RISK_LEVEL'. ls-coltext = 'Risk (C/H/M)'.
  ls-scrtext_l = 'C=Critical H=High M=Medium'. ls-scrtext_m = 'Risk Level'. ls-scrtext_s = 'Risk'.
  ls-edit = 'X'. ls-outputlen = 12.
  APPEND ls TO gt_fcat.

  CLEAR ls.
  ls-fieldname = 'SUGGESTED_ACTION'. ls-coltext = 'Action (RM/EX/RV)'.
  ls-scrtext_l = 'RM=Remove EX=Exempt RV=Review'. ls-scrtext_m = 'Action'. ls-scrtext_s = 'Act'.
  ls-edit = 'X'. ls-outputlen = 15.
  APPEND ls TO gt_fcat.
ENDFORM.





*&---------------------------------------------------------------------*
FORM save_ff_roles.
  LOOP AT gt_ff ASSIGNING FIELD-SYMBOL(<fs>).
    IF <fs>-agr_name IS INITIAL. CONTINUE. ENDIF.

    SELECT SINGLE agr_name FROM agr_define WHERE agr_name = @<fs>-agr_name INTO @DATA(lv_rc).
    IF sy-subrc <> 0.
      MESSAGE i306(zmsg_iam07) WITH <fs>-agr_name DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.

    IF <fs>-owner IS NOT INITIAL.
      SELECT SINGLE bname FROM usr02 WHERE bname = @<fs>-owner INTO @DATA(lv_oc).
      IF sy-subrc <> 0.
        MESSAGE i307(zmsg_iam07) WITH <fs>-owner DISPLAY LIKE 'E'.
        RETURN.
      ENDIF.
    ENDIF.

    IF <fs>-backup_owner IS NOT INITIAL.
      SELECT SINGLE bname FROM usr02 WHERE bname = @<fs>-backup_owner INTO @DATA(lv_bc).
      IF sy-subrc <> 0.
        MESSAGE i307(zmsg_iam07) WITH <fs>-backup_owner DISPLAY LIKE 'E'.
        RETURN.
      ENDIF.
    ENDIF.

    <fs>-changed_by = sy-uname.
    GET TIME STAMP FIELD <fs>-changed_at.
    GET TIME STAMP FIELD <fs>-local_last_changed_at.
  ENDLOOP.

  LOOP AT gt_ff_orig INTO DATA(ls_o).
    READ TABLE gt_ff WITH KEY agr_name = ls_o-agr_name TRANSPORTING NO FIELDS.
    IF sy-subrc <> 0.
      DELETE FROM ziam_ff_role WHERE agr_name = @ls_o-agr_name.
    ENDIF.
  ENDLOOP.

  DELETE gt_ff WHERE agr_name IS INITIAL.
  IF gt_ff IS NOT INITIAL.
    MODIFY ziam_ff_role FROM TABLE @gt_ff.
  ENDIF.

  IF sy-subrc = 0.
    COMMIT WORK AND WAIT.
    gt_ff_orig = gt_ff.
    MESSAGE s014(zmsg_iam07).
  ELSE.
    CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.
    MESSAGE i013(zmsg_iam07) DISPLAY LIKE 'E'.
  ENDIF.
ENDFORM.

*&---------------------------------------------------------------------*
FORM save_sod_rules.
  LOOP AT gt_sod ASSIGNING FIELD-SYMBOL(<fs>).
    IF <fs>-rule_id IS INITIAL. CONTINUE. ENDIF.

    IF <fs>-conflict_role1 IS INITIAL OR <fs>-conflict_role2 IS INITIAL.
      MESSAGE i308(zmsg_iam07) WITH <fs>-rule_id DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.

    IF <fs>-conflict_role1 = <fs>-conflict_role2.
      MESSAGE i309(zmsg_iam07) WITH <fs>-rule_id DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.

    SELECT SINGLE agr_name FROM agr_define WHERE agr_name = @<fs>-conflict_role1 INTO @DATA(lv1).
    IF sy-subrc <> 0.
      MESSAGE i310(zmsg_iam07) WITH <fs>-rule_id <fs>-conflict_role1 DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.

    SELECT SINGLE agr_name FROM agr_define WHERE agr_name = @<fs>-conflict_role2 INTO @DATA(lv2).
    IF sy-subrc <> 0.
      MESSAGE i310(zmsg_iam07) WITH <fs>-rule_id <fs>-conflict_role2 DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.

    <fs>-rule_type = 'R'.
  ENDLOOP.

  LOOP AT gt_sod_orig INTO DATA(ls_o).
    READ TABLE gt_sod WITH KEY rule_id = ls_o-rule_id TRANSPORTING NO FIELDS.
    IF sy-subrc <> 0.
      DELETE FROM ziam_sod_rule WHERE rule_id = @ls_o-rule_id.
    ENDIF.
  ENDLOOP.

  DELETE gt_sod WHERE rule_id IS INITIAL.
  IF gt_sod IS NOT INITIAL.
    MODIFY ziam_sod_rule FROM TABLE @gt_sod.
  ENDIF.

  IF sy-subrc = 0.
    COMMIT WORK AND WAIT.
    gt_sod_orig = gt_sod.
    MESSAGE s014(zmsg_iam07).
  ELSE.
    CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.
    MESSAGE i013(zmsg_iam07) DISPLAY LIKE 'E'.
  ENDIF.
ENDFORM.
