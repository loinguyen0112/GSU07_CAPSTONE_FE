CLASS zcl_iam_sod_admin DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES:
      BEGIN OF ty_conflict,
        target_user      TYPE xubname,
        rule_id          TYPE char20,
        rule_name        TYPE char100,
        role_1           TYPE agr_name,
        role_2           TYPE agr_name,
        risk_level       TYPE char1,
        is_exempt        TYPE abap_bool,
        exempt_reason    TYPE char255,
        suggested_action TYPE char255,
        is_locked        TYPE abap_bool,
        last_login       TYPE xuldate,
      END OF ty_conflict,
      tt_conflict TYPE STANDARD TABLE OF ty_conflict WITH EMPTY KEY,
      tt_user     TYPE SORTED TABLE OF xubname WITH UNIQUE KEY table_line.

    CLASS-METHODS scan_users
      IMPORTING
        it_users TYPE tt_user
      RETURNING
        VALUE(rt_conflicts) TYPE tt_conflict.

    CLASS-METHODS remove_conflict_role
      IMPORTING
        iv_user    TYPE xubname
        iv_rule_id TYPE char20
        iv_role    TYPE agr_name
        iv_reason  TYPE char255
      EXPORTING
        ev_success TYPE abap_bool
        ev_message TYPE string.
ENDCLASS.


CLASS zcl_iam_sod_admin IMPLEMENTATION.
  METHOD scan_users.
    DATA lt_requested_roles TYPE zcl_iam_sod_request_checker=>tt_role.

    LOOP AT it_users INTO DATA(lv_user).
      DATA(lt_user_conflicts) = zcl_iam_sod_request_checker=>check_role_set(
        iv_target_user     = lv_user
        it_requested_roles = lt_requested_roles ).

      LOOP AT lt_user_conflicts INTO DATA(ls_user_conflict).
        APPEND VALUE ty_conflict(
          target_user      = lv_user
          rule_id          = ls_user_conflict-rule_id
          rule_name        = ls_user_conflict-rule_name
          role_1           = ls_user_conflict-role_1
          role_2           = ls_user_conflict-role_2
          risk_level       = ls_user_conflict-risk_level
          is_exempt        = ls_user_conflict-is_exempt
          exempt_reason    = ls_user_conflict-exempt_reason
          suggested_action = ls_user_conflict-suggested_action
          is_locked        = ls_user_conflict-is_locked
          last_login       = ls_user_conflict-last_login ) TO rt_conflicts.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.

  METHOD remove_conflict_role.
    ev_success = abap_false.

    AUTHORITY-CHECK OBJECT 'ZIAM_REQ'
      ID 'ACTVT' FIELD '06'.
    IF sy-subrc <> 0.
      MESSAGE ID 'ZMSG_IAM07' TYPE 'S' NUMBER '010'
        WITH 'ZIAM_REQ' '06' INTO ev_message.
      RETURN.
    ENDIF.

    IF iv_reason IS INITIAL.
      MESSAGE ID 'ZMSG_IAM07' TYPE 'S' NUMBER '021'
        INTO ev_message.
      RETURN.
    ENDIF.

    SELECT SINGLE conflict_role1, conflict_role2
      FROM ziam_sod_rule
      WHERE rule_id = @iv_rule_id
        AND rule_type = 'R'
      INTO @DATA(ls_rule).
    IF sy-subrc <> 0.
      MESSAGE ID 'ZMSG_IAM07' TYPE 'S' NUMBER '300'
        WITH iv_rule_id INTO ev_message.
      RETURN.
    ENDIF.
    IF iv_role <> ls_rule-conflict_role1
       AND iv_role <> ls_rule-conflict_role2.
      MESSAGE ID 'ZMSG_IAM07' TYPE 'S' NUMBER '301'
        WITH iv_role iv_rule_id INTO ev_message.
      RETURN.
    ENDIF.

    GET TIME STAMP FIELD DATA(lv_now).
    SELECT grant_id
      FROM ziam_ff_grant
      WHERE target_user = @iv_user
        AND agr_name    = @iv_role
        AND status      = 'ACTIVE'
        AND end_at      > @lv_now
      INTO TABLE @DATA(lt_active_grants).
    IF lt_active_grants IS NOT INITIAL.
      SORT lt_active_grants BY grant_id DESCENDING.
      DATA(lv_grant_id) = lt_active_grants[ 1 ]-grant_id.
      MESSAGE ID 'ZMSG_IAM07' TYPE 'S' NUMBER '302'
        WITH iv_role lv_grant_id INTO ev_message.
      RETURN.
    ENDIF.

    DATA lt_activitygroups TYPE STANDARD TABLE OF bapiagr WITH EMPTY KEY.
    DATA lt_return TYPE STANDARD TABLE OF bapiret2 WITH EMPTY KEY.
    CALL FUNCTION 'BAPI_USER_GET_DETAIL'
      EXPORTING
        username       = iv_user
        cache_results  = space
      TABLES
        activitygroups = lt_activitygroups
        return         = lt_return.

    LOOP AT lt_return INTO DATA(ls_read_return) WHERE type CA 'AEX'.
      ev_message = ls_read_return-message.
      RETURN.
    ENDLOOP.

    READ TABLE lt_activitygroups ASSIGNING FIELD-SYMBOL(<ls_activitygroup>)
      WITH KEY agr_name = iv_role.
    IF sy-subrc <> 0.
      MESSAGE ID 'ZMSG_IAM07' TYPE 'S' NUMBER '303'
        WITH iv_role iv_user INTO ev_message.
      RETURN.
    ENDIF.
    IF <ls_activitygroup>-from_dat > sy-datum
       OR <ls_activitygroup>-to_dat < sy-datum.
      MESSAGE ID 'ZMSG_IAM07' TYPE 'S' NUMBER '304'
        WITH iv_role iv_user INTO ev_message.
      RETURN.
    ENDIF.
    DELETE lt_activitygroups WHERE agr_name = iv_role.

    CLEAR lt_return.
    CALL FUNCTION 'BAPI_USER_ACTGROUPS_ASSIGN'
      EXPORTING
        username       = iv_user
      TABLES
        activitygroups = lt_activitygroups
        return         = lt_return.

    LOOP AT lt_return INTO DATA(ls_return) WHERE type CA 'AEX'.
      ev_message = ls_return-message.
      CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.
      RETURN.
    ENDLOOP.
    TRY.
        DATA(lv_log_id) = cl_system_uuid=>create_uuid_c32_static( ).
      CATCH cx_uuid_error.
        CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.
        MESSAGE ID 'ZMSG_IAM07' TYPE 'S' NUMBER '027'
          INTO ev_message.
        RETURN.
    ENDTRY.

    DATA(ls_audit) = VALUE ziam_aud_log2(
      log_id        = lv_log_id
      action_type   = 'SOD_ROLE_RM'
      target_user   = iv_user
      performed_by  = sy-uname
      old_value     = |Rule { iv_rule_id }; Role { iv_role }|
      new_value     = |Reason: { iv_reason }|
      timestamp     = lv_now
      source_module = 'RUSERS02' ).
    INSERT ziam_aud_log2 FROM @ls_audit.
    IF sy-subrc <> 0.
      CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.
      MESSAGE ID 'ZMSG_IAM07' TYPE 'S' NUMBER '027'
        INTO ev_message.
      RETURN.
    ENDIF.
    CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
      EXPORTING
        wait = abap_true.

    ev_success = abap_true.
    MESSAGE ID 'ZMSG_IAM07' TYPE 'S' NUMBER '305'
      WITH iv_role iv_user INTO ev_message.
  ENDMETHOD.
ENDCLASS.
