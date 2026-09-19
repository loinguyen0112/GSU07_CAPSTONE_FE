CLASS zbp_i_rusers02 DEFINITION PUBLIC ABSTRACT FINAL FOR BEHAVIOR OF zi_rusers02.
ENDCLASS.

CLASS zbp_i_rusers02 IMPLEMENTATION.
ENDCLASS.

CLASS lhc_User DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR User RESULT result.
    METHODS read FOR READ
      IMPORTING keys FOR READ User RESULT result.
    METHODS lock FOR LOCK
      IMPORTING keys FOR LOCK User.
    METHODS checkRoles FOR MODIFY
      IMPORTING keys FOR ACTION User~checkRoles RESULT result.
    METHODS checkSod FOR MODIFY
      IMPORTING keys FOR ACTION User~checkSod RESULT result.
    METHODS lockUser FOR MODIFY
      IMPORTING keys FOR ACTION User~lockUser RESULT result.
    METHODS unlockUser FOR MODIFY
      IMPORTING keys FOR ACTION User~unlockUser RESULT result.
    METHODS write_audit
      IMPORTING iv_action TYPE char20 iv_user TYPE xubname
                iv_old TYPE string OPTIONAL iv_new TYPE string OPTIONAL
      RETURNING VALUE(rv_ok) TYPE abap_bool.
    METHODS has_admin_authority RETURNING VALUE(rv_ok) TYPE abap_bool.
ENDCLASS.

CLASS lhc_User IMPLEMENTATION.

  METHOD has_admin_authority.
    AUTHORITY-CHECK OBJECT 'ZIAM_REQ' ID 'ACTVT' FIELD '06'.
    rv_ok = xsdbool( sy-subrc = 0 ).
  ENDMETHOD.

  METHOD write_audit.
    rv_ok = abap_false.
    TRY.
        DATA(lv_log_id) = cl_system_uuid=>create_uuid_c32_static( ).
      CATCH cx_uuid_error.
        RETURN.
    ENDTRY.
    GET TIME STAMP FIELD DATA(lv_now).
    INSERT ziam_aud_log2 FROM @( VALUE ziam_aud_log2(
      log_id        = lv_log_id
      action_type   = iv_action
      target_user   = iv_user
      performed_by  = sy-uname
      old_value     = iv_old
      new_value     = iv_new
      timestamp     = lv_now
      source_module = 'RUSERS02' ) ).
    rv_ok = xsdbool( sy-subrc = 0 ).
  ENDMETHOD.

  METHOD get_global_authorizations.
    AUTHORITY-CHECK OBJECT 'ZIAM_REQ' ID 'ACTVT' FIELD '06'.
    DATA(lv_auth) = COND #( WHEN sy-subrc = 0
                            THEN if_abap_behv=>auth-allowed
                            ELSE if_abap_behv=>auth-unauthorized ).
    result-%action-lockUser   = lv_auth.
    result-%action-unlockUser = lv_auth.
    result-%action-checkRoles = lv_auth.
    result-%action-checkSod   = lv_auth.
  ENDMETHOD.

  METHOD read.
    CHECK keys IS NOT INITIAL.
    SELECT FROM zi_rusers02
      FIELDS UserName, UserType, UserGroup, UserFlag, CreatedDate,
             LastLogonDate, LastLogonTime, ValidFrom, ValidTo,
             UserStatus, FullName, Department, Email
      FOR ALL ENTRIES IN @keys
      WHERE UserName = @keys-UserName
      INTO CORRESPONDING FIELDS OF TABLE @result.
  ENDMETHOD.

  METHOD lock.
    "USR02 changes are serialized by the BAPIs in the actions.
  ENDMETHOD.

  METHOD lockUser.
    IF has_admin_authority( ) = abap_false.
      LOOP AT keys INTO DATA(ls_key).
        APPEND VALUE #( %tky = ls_key-%tky ) TO failed-user.
        APPEND VALUE #( %tky = ls_key-%tky %msg = new_message(
          id = 'ZMSG_IAM07' number = '010'
          severity = if_abap_behv_message=>severity-error
          v1 = 'ZIAM_REQ' v2 = '06' ) ) TO reported-user.
      ENDLOOP.
      RETURN.
    ENDIF.
    LOOP AT keys INTO ls_key.
      DATA lt_return TYPE STANDARD TABLE OF bapiret2 WITH EMPTY KEY.
      CALL FUNCTION 'BAPI_USER_LOCK'
        EXPORTING username = ls_key-UserName
        TABLES return = lt_return.
      IF line_exists( lt_return[ type = 'E' ] )
         OR line_exists( lt_return[ type = 'A' ] )
         OR line_exists( lt_return[ type = 'X' ] ).
        APPEND VALUE #( %tky = ls_key-%tky ) TO failed-user.
        CONTINUE.
      ENDIF.
      CALL FUNCTION 'BAPI_TRANSACTION_COMMIT' EXPORTING wait = abap_true.
      IF write_audit( iv_action = 'LOCK' iv_user = ls_key-UserName
                      iv_new = 'Locked by Fiori action' ) = abap_true.
        APPEND VALUE #( %tky = ls_key-%tky ) TO result.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD unlockUser.
    IF has_admin_authority( ) = abap_false.
      LOOP AT keys INTO DATA(ls_key).
        APPEND VALUE #( %tky = ls_key-%tky ) TO failed-user.
        APPEND VALUE #( %tky = ls_key-%tky %msg = new_message(
          id = 'ZMSG_IAM07' number = '010'
          severity = if_abap_behv_message=>severity-error
          v1 = 'ZIAM_REQ' v2 = '06' ) ) TO reported-user.
      ENDLOOP.
      RETURN.
    ENDIF.
    LOOP AT keys INTO ls_key.
      DATA lt_return TYPE STANDARD TABLE OF bapiret2 WITH EMPTY KEY.
      CALL FUNCTION 'BAPI_USER_UNLOCK'
        EXPORTING username = ls_key-UserName
        TABLES return = lt_return.
      IF line_exists( lt_return[ type = 'E' ] )
         OR line_exists( lt_return[ type = 'A' ] )
         OR line_exists( lt_return[ type = 'X' ] ).
        APPEND VALUE #( %tky = ls_key-%tky ) TO failed-user.
        CONTINUE.
      ENDIF.
      CALL FUNCTION 'BAPI_TRANSACTION_COMMIT' EXPORTING wait = abap_true.
      IF write_audit( iv_action = 'UNLOCK' iv_user = ls_key-UserName
                      iv_new = 'Unlocked by Fiori action' ) = abap_true.
        APPEND VALUE #( %tky = ls_key-%tky ) TO result.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD checkRoles.
    LOOP AT keys INTO DATA(ls_key).
      DATA lt_roles TYPE STANDARD TABLE OF bapiagr WITH EMPTY KEY.
      DATA lt_return TYPE STANDARD TABLE OF bapiret2 WITH EMPTY KEY.
      CALL FUNCTION 'BAPI_USER_GET_DETAIL'
        EXPORTING username = ls_key-UserName cache_results = space
        TABLES activitygroups = lt_roles return = lt_return.
      IF line_exists( lt_return[ type = 'E' ] )
         OR line_exists( lt_return[ type = 'A' ] ).
        APPEND VALUE #( %tky = ls_key-%tky ) TO failed-user.
        CONTINUE.
      ENDIF.
      DATA(lv_count) = lines( lt_roles ).
      IF write_audit( iv_action = 'CHECK_AUTH' iv_user = ls_key-UserName
                      iv_new = |Roles found: { lv_count }| ) = abap_true.
        APPEND VALUE #( %tky = ls_key-%tky ) TO result.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD checkSod.
    LOOP AT keys INTO DATA(ls_key).
      DATA(lt_conflicts) = zcl_iam_sod_checker=>run(
        iv_uname = ls_key-UserName ).
      DATA(lv_count) = lines( lt_conflicts ).
      DATA(lv_summary) = COND string(
        WHEN lt_conflicts IS INITIAL THEN 'No active SoD conflict'
        ELSE |Conflicts found: { lv_count }| ).
      IF write_audit( iv_action = 'CHECK_SOD' iv_user = ls_key-UserName
                      iv_new = lv_summary ) = abap_true.
        APPEND VALUE #( %tky = ls_key-%tky ) TO result.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.

CLASS lsc_ZI_RUSERS02 DEFINITION INHERITING FROM cl_abap_behavior_saver.
  PROTECTED SECTION.
    METHODS finalize REDEFINITION.
    METHODS check_before_save REDEFINITION.
    METHODS save REDEFINITION.
    METHODS cleanup REDEFINITION.
    METHODS cleanup_finalize REDEFINITION.
ENDCLASS.

CLASS lsc_ZI_RUSERS02 IMPLEMENTATION.
  METHOD finalize.
  ENDMETHOD.
  METHOD check_before_save.
  ENDMETHOD.
  METHOD save.
  ENDMETHOD.
  METHOD cleanup.
  ENDMETHOD.
  METHOD cleanup_finalize.
  ENDMETHOD.
ENDCLASS.
