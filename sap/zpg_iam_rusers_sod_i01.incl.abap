*&---------------------------------------------------------------------*
*& Include ZPG_IAM_RUSERS_SOD_I01
*& Global declarations plus SoD review forms for ZPG_RUSERS_02
*& This include is placed after global DATA and before the local class.
*&---------------------------------------------------------------------*

Wall time: 0.2 seconds
Output:
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

Output:
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
    MESSAGE 'Select at least one user before checking SoD' TYPE 'S' DISPLAY LIKE 'W'.
    RETURN.
  ENDIF.

  lt_conflicts = zcl_iam_sod_admin=>scan_users( lt_users ).
  LOOP AT lt_conflicts INTO DATA(ls_conflict).
    APPEND CORRESPONDING #( ls_conflict ) TO lt_popup.
  ENDLOOP.
  IF lt_popup IS INITIAL.
    MESSAGE 'No SoD conflicts found for selected users' TYPE 'S'.
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

  IF ps_conflict-is_exempt = abap_true.
    MESSAGE |Rule { ps_conflict-rule_id } is currently exempt; no role was removed| TYPE 'S' DISPLAY LIKE 'W'.
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
    MESSAGE 'Select exactly one of the two conflicting roles' TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  APPEND VALUE #( tabname = 'ZIAM_AUD_LOG2' fieldname = 'NEW_VALUE'
                  fieldtext = 'Review reason' field_obl = 'X' ) TO lt_fields.
  CALL FUNCTION 'POPUP_GET_VALUES'
    EXPORTING popup_title = |Review SoD rule { ps_conflict-rule_id }|
    TABLES    fields      = lt_fields.
  IF sy-subrc <> 0.
    RETURN.
  ENDIF.
  READ TABLE lt_fields INDEX 1 INTO DATA(ls_reason).
  IF ls_reason-value IS INITIAL.
    MESSAGE 'Review reason is mandatory' TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  CALL FUNCTION 'POPUP_TO_CONFIRM'
    EXPORTING
      titlebar              = 'Confirm SoD remediation'
      text_question         = |Remove role { lv_role } from user { ps_conflict-target_user }?|
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
