CLASS zcl_iam_access_ctrl DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES tt_bname_range TYPE RANGE OF xubname.
    TYPES tt_log TYPE STANDARD TABLE OF string WITH EMPTY KEY.

    METHODS constructor
      IMPORTING
        iv_simulation TYPE abap_bool DEFAULT abap_true.

    METHODS run_inactivity
      IMPORTING
        it_bname     TYPE tt_bname_range OPTIONAL
        iv_keydate   TYPE sy-datum OPTIONAL
        iv_warn_from TYPE i DEFAULT 0
        iv_lock_at   TYPE i DEFAULT 0.

    METHODS run_firefighter_expiry.

    METHODS get_log
      RETURNING
        VALUE(rt_log) TYPE tt_log.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_user,
        bname      TYPE usr02-bname,
        ustyp      TYPE usr02-ustyp,
        usrgrp     TYPE usr02-class,
        uflag      TYPE usr02-uflag,
        erdat      TYPE usr02-erdat,
        trdat      TYPE usr02-trdat,
        gltgv      TYPE usr02-gltgv,
        gltgb      TYPE usr02-gltgb,
        idadtype   TYPE usr21-idadtype,
      END OF ty_user.
    TYPES tt_users TYPE STANDARD TABLE OF ty_user WITH EMPTY KEY.
    TYPES tt_bapiagr TYPE STANDARD TABLE OF bapiagr WITH DEFAULT KEY.
    TYPES tt_bapiret2 TYPE STANDARD TABLE OF bapiret2 WITH DEFAULT KEY.

    DATA mv_simulation TYPE abap_bool.
    DATA mt_log TYPE tt_log.

    METHODS add_log
      IMPORTING
        iv_level TYPE c
        iv_text  TYPE string.

    METHODS check_auth
      IMPORTING
        iv_actvt TYPE activ_auth
      RETURNING
        VALUE(rv_ok) TYPE abap_bool.

    METHODS get_cfg_threshold
      IMPORTING
        iv_rule_id TYPE ziam_ctrl_cfg-rule_id
        iv_default TYPE i
      RETURNING
        VALUE(rv_value) TYPE i.

    METHODS is_excluded
      IMPORTING
        is_user    TYPE ty_user
        iv_keydate TYPE sy-datum
      RETURNING
        VALUE(rv_excluded) TYPE abap_bool.

    METHODS process_user
      IMPORTING
        is_user      TYPE ty_user
        iv_keydate   TYPE sy-datum
        iv_warn_from TYPE i
        iv_lock_at   TYPE i.

    METHODS process_user_locked
      IMPORTING
        is_user      TYPE ty_user
        iv_keydate   TYPE sy-datum
        iv_warn_from TYPE i
        iv_lock_at   TYPE i.

    METHODS acquire_user_lock
      IMPORTING
        iv_user TYPE xubname
      RETURNING
        VALUE(rv_ok) TYPE abap_bool.

    METHODS release_user_lock
      IMPORTING
        iv_user TYPE xubname.

    METHODS resolve_email
      IMPORTING
        iv_bname TYPE xubname
      EXPORTING
        ev_email   TYPE ad_smtpadr
        ev_ok      TYPE abap_bool
        ev_message TYPE char255.

    METHODS send_warning
      IMPORTING
        iv_bname    TYPE xubname
        iv_email    TYPE ad_smtpadr
        iv_days     TYPE i
        iv_lockdate TYPE sy-datum
      EXPORTING
        ev_ok      TYPE abap_bool
        ev_message TYPE char255.

    METHODS write_audit
      IMPORTING
        iv_action      TYPE char20
        iv_target_user TYPE xubname
        iv_old_value   TYPE char255 OPTIONAL
        iv_new_value   TYPE char255 OPTIONAL
        iv_source      TYPE char10
      RETURNING
        VALUE(rv_ok) TYPE abap_bool.

    METHODS write_sal
      IMPORTING
        iv_subid  TYPE c
        iv_user   TYPE xubname
        iv_role   TYPE agr_name
        iv_req_id TYPE ziam_ff_grant-grant_id
        iv_result TYPE char20.

    METHODS get_roles
      IMPORTING
        iv_user TYPE xubname
      EXPORTING
        et_roles   TYPE tt_bapiagr
        ev_ok      TYPE abap_bool
        ev_message TYPE char255.

    METHODS has_bapi_error
      IMPORTING
        it_return TYPE tt_bapiret2
      RETURNING
        VALUE(rv_error) TYPE abap_bool.

    METHODS bapi_message
      IMPORTING
        it_return TYPE tt_bapiret2
      RETURNING
        VALUE(rv_message) TYPE char255.

    METHODS verify_unrelated_roles
      IMPORTING
        it_before TYPE tt_bapiagr
        it_after  TYPE tt_bapiagr
        iv_target TYPE agr_name
      RETURNING
        VALUE(rv_ok) TYPE abap_bool.

    METHODS assign_roles
      IMPORTING
        iv_user           TYPE xubname
        iv_target         TYPE agr_name
        it_before         TYPE tt_bapiagr
        it_desired        TYPE tt_bapiagr
        iv_expect_present TYPE abap_bool
        iv_expect_from    TYPE sy-datum OPTIONAL
        iv_expect_to      TYPE sy-datum OPTIONAL
      EXPORTING
        ev_ok      TYPE abap_bool
        ev_message TYPE char255.

    METHODS close_grant
      IMPORTING
        iv_expired TYPE abap_bool
        iv_reason  TYPE char255 OPTIONAL
      CHANGING
        cs_grant TYPE ziam_ff_grant.

    METHODS close_grant_locked
      IMPORTING
        iv_expired TYPE abap_bool
        iv_reason  TYPE char255 OPTIONAL
      CHANGING
        cs_grant TYPE ziam_ff_grant.

    METHODS process_pending_ff_grants.

    METHODS recover_firefighter_work.
ENDCLASS.


CLASS zcl_iam_access_ctrl IMPLEMENTATION.
  METHOD constructor.
    mv_simulation = iv_simulation.
  ENDMETHOD.

  METHOD add_log.
    APPEND |{ iv_level } { iv_text }| TO mt_log.
  ENDMETHOD.

  METHOD get_log.
    rt_log = mt_log.
  ENDMETHOD.

  METHOD check_auth.
    AUTHORITY-CHECK OBJECT 'ZIAM_REQ'
      ID 'ACTVT' FIELD iv_actvt.
    rv_ok = xsdbool( sy-subrc = 0 ).
    IF rv_ok = abap_false.
      add_log(
        iv_level = 'E'
        iv_text  = |Missing authorization ZIAM_REQ ACTVT={ iv_actvt }| ).
    ENDIF.
  ENDMETHOD.

  METHOD acquire_user_lock.
    IF mv_simulation = abap_true.
      rv_ok = abap_true.
      RETURN.
    ENDIF.

    CALL FUNCTION 'ENQUEUE_EUSR02'
      EXPORTING
        bname  = iv_user
        _scope = '1'
        _wait  = space
      EXCEPTIONS
        foreign_lock   = 1
        system_failure = 2
        OTHERS         = 3.
    rv_ok = xsdbool( sy-subrc = 0 ).
  ENDMETHOD.

  METHOD release_user_lock.
    IF mv_simulation = abap_true.
      RETURN.
    ENDIF.

    CALL FUNCTION 'DEQUEUE_EUSR02'
      EXPORTING
        bname      = iv_user
        _scope     = '1'
        _synchron = abap_true.
  ENDMETHOD.

  METHOD get_cfg_threshold.
    rv_value = iv_default.
    SELECT SINGLE days_threshold
      FROM ziam_ctrl_cfg
      WHERE rule_id   = @iv_rule_id
        AND is_active = @abap_true
      INTO @DATA(lv_value).
    IF sy-subrc = 0 AND lv_value > 0.
      rv_value = lv_value.
    ENDIF.
  ENDMETHOD.

  METHOD is_excluded.
    SELECT SINGLE excl_id
      FROM ziam_ctrl_excl
      WHERE is_active = @abap_true
        AND ( valid_from = '00000000' OR valid_from <= @iv_keydate )
        AND ( valid_to   = '00000000' OR valid_to   >= @iv_keydate )
        AND ( ( scope = 'U' AND bname  = @is_user-bname )
           OR ( scope = 'G' AND usrgrp = @is_user-usrgrp ) )
      INTO @DATA(lv_excl_id).
    rv_excluded = xsdbool( sy-subrc = 0 ).
  ENDMETHOD.

  METHOD write_audit.
    DATA ls_audit TYPE ziam_aud_log2.

    TRY.
        ls_audit-log_id = cl_system_uuid=>create_uuid_c32_static( ).
      CATCH cx_uuid_error.
        rv_ok = abap_false.
        RETURN.
    ENDTRY.

    ls_audit-action_type   = iv_action.
    ls_audit-target_user   = iv_target_user.
    ls_audit-performed_by  = sy-uname.
    ls_audit-old_value     = iv_old_value.
    ls_audit-new_value     = iv_new_value.
    GET TIME STAMP FIELD ls_audit-timestamp.
    ls_audit-source_module = iv_source.

    INSERT ziam_aud_log2 FROM @ls_audit.
    rv_ok = xsdbool( sy-subrc = 0 ).
  ENDMETHOD.

  METHOD write_sal.
    cl_sal_write_event=>write_customer_evts(
      id_subid = iv_subid
      id_var_a = iv_user
      id_var_b = iv_role
      id_var_c = iv_req_id
      id_var_d = iv_result ).
  ENDMETHOD.

  METHOD run_inactivity.
    IF check_auth( '16' ) = abap_false.
      RETURN.
    ENDIF.

    DATA(lv_keydate) = iv_keydate.
    IF lv_keydate IS INITIAL.
      lv_keydate = sy-datum.
    ENDIF.

    DATA(lv_warn_from) = iv_warn_from.
    IF lv_warn_from <= 0.
      lv_warn_from = get_cfg_threshold(
        iv_rule_id = 'WARN_FROM'
        iv_default = 83 ).
    ENDIF.

    DATA(lv_lock_at) = iv_lock_at.
    IF lv_lock_at <= 0.
      lv_lock_at = get_cfg_threshold(
        iv_rule_id = 'LOCK_AT'
        iv_default = 90 ).
    ENDIF.

    IF lv_warn_from < 1 OR lv_lock_at <= lv_warn_from.
      add_log(
        iv_level = 'E'
        iv_text  = |Invalid thresholds: warn={ lv_warn_from }, lock={ lv_lock_at }| ).
      RETURN.
    ENDIF.

    DATA lt_users TYPE tt_users.
    IF it_bname IS INITIAL.
      SELECT u~bname,
             u~ustyp,
             u~class AS usrgrp,
             u~uflag,
             u~erdat,
             u~trdat,
             u~gltgv,
             u~gltgb,
             i~idadtype
        FROM usr02 AS u
        LEFT OUTER JOIN usr21 AS i
          ON i~bname = u~bname
        WHERE u~ustyp = 'A'
          AND ( u~gltgv = '00000000' OR u~gltgv <= @lv_keydate )
          AND ( u~gltgb = '00000000' OR u~gltgb >= @lv_keydate )
        INTO TABLE @lt_users.
    ELSE.
      SELECT u~bname,
             u~ustyp,
             u~class AS usrgrp,
             u~uflag,
             u~erdat,
             u~trdat,
             u~gltgv,
             u~gltgb,
             i~idadtype
        FROM usr02 AS u
        LEFT OUTER JOIN usr21 AS i
          ON i~bname = u~bname
        WHERE u~ustyp = 'A'
          AND u~bname IN @it_bname
          AND ( u~gltgv = '00000000' OR u~gltgv <= @lv_keydate )
          AND ( u~gltgb = '00000000' OR u~gltgb >= @lv_keydate )
        INTO TABLE @lt_users.
    ENDIF.

    add_log(
      iv_level = 'I'
      iv_text  = |Inactivity scan candidates={ lines( lt_users ) }, key date={ lv_keydate }| ).

    LOOP AT lt_users INTO DATA(ls_user).
      IF ls_user-bname = sy-uname
         OR ls_user-bname = 'SAP*'
         OR ls_user-bname = 'DDIC'
         OR ls_user-idadtype = '01'.
        CONTINUE.
      ENDIF.

      IF is_excluded(
           is_user    = ls_user
           iv_keydate = lv_keydate ) = abap_true.
        add_log(
          iv_level = 'I'
          iv_text  = |Excluded inactivity account { ls_user-bname }| ).
        CONTINUE.
      ENDIF.

      process_user(
        is_user      = ls_user
        iv_keydate   = lv_keydate
        iv_warn_from = lv_warn_from
        iv_lock_at   = lv_lock_at ).
    ENDLOOP.
  ENDMETHOD.

  METHOD process_user.
    IF acquire_user_lock( is_user-bname ) = abap_false.
      add_log(
        iv_level = 'W'
        iv_text  = |Skipped busy user { is_user-bname }; another process owns the lock| ).
      RETURN.
    ENDIF.

    DATA ls_fresh TYPE ty_user.
    SELECT SINGLE
           u~bname,
           u~ustyp,
           u~class AS usrgrp,
           u~uflag,
           u~erdat,
           u~trdat,
           u~gltgv,
           u~gltgb,
           i~idadtype
      FROM usr02 AS u
      LEFT OUTER JOIN usr21 AS i
        ON i~bname = u~bname
      WHERE u~bname = @is_user-bname
      INTO CORRESPONDING FIELDS OF @ls_fresh.

    IF sy-subrc = 0
       AND ls_fresh-ustyp = 'A'
       AND ls_fresh-bname <> sy-uname
       AND ls_fresh-bname <> 'SAP*'
       AND ls_fresh-bname <> 'DDIC'
       AND ls_fresh-idadtype <> '01'
       AND is_excluded(
             is_user    = ls_fresh
             iv_keydate = iv_keydate ) = abap_false.
      process_user_locked(
        is_user      = ls_fresh
        iv_keydate   = iv_keydate
        iv_warn_from = iv_warn_from
        iv_lock_at   = iv_lock_at ).
    ELSE.
      add_log(
        iv_level = 'I'
        iv_text  = |Skipped { is_user-bname } after locked recheck| ).
    ENDIF.

    release_user_lock( is_user-bname ).
  ENDMETHOD.

  METHOD process_user_locked.
    DATA lv_anchor TYPE sy-datum.
    DATA lv_anchor_kind TYPE c LENGTH 1.

    IF is_user-trdat IS NOT INITIAL.
      lv_anchor = is_user-trdat.
      lv_anchor_kind = 'L'.
    ELSE.
      lv_anchor = is_user-erdat.
      lv_anchor_kind = 'C'.
    ENDIF.

    IF lv_anchor IS INITIAL OR lv_anchor > iv_keydate.
      add_log(
        iv_level = 'W'
        iv_text  = |Skipped { is_user-bname }: invalid activity anchor { lv_anchor }| ).
      RETURN.
    ENDIF.

    DATA(lv_days) = iv_keydate - lv_anchor.
    SELECT SINGLE *
      FROM ziam_ctrl_case
      WHERE bname = @is_user-bname
      INTO @DATA(ls_case).

    IF sy-subrc <> 0.
      CLEAR ls_case.
      ls_case-bname = is_user-bname.
    ENDIF.

    DATA(lv_new_episode) = xsdbool(
      ls_case-anchor_date IS INITIAL OR
      ls_case-anchor_date <> lv_anchor ).

    IF lv_new_episode = abap_true.
      ls_case-anchor_date = lv_anchor.
      ls_case-anchor_kind = lv_anchor_kind.
      CLEAR:
        ls_case-last_warn,
        ls_case-warn_count,
        ls_case-lock_at,
        ls_case-retry_count,
        ls_case-last_error.
      ls_case-status = 'OPEN'.
    ENDIF.

    IF lv_days < iv_warn_from.
      IF ls_case-status IS NOT INITIAL AND ls_case-status <> 'CLOSED'.
        IF mv_simulation = abap_true.
          add_log(
            iv_level = 'S'
            iv_text  = |Would close inactivity case for { is_user-bname } after login| ).
          RETURN.
        ENDIF.

        ls_case-status = 'CLOSED'.
        ls_case-changed_by = sy-uname.
        GET TIME STAMP FIELD ls_case-changed_at.
        MODIFY ziam_ctrl_case FROM @ls_case.
        IF sy-subrc = 0 AND
           write_audit(
             iv_action      = 'INA_CASE_CLOSE'
             iv_target_user = is_user-bname
             iv_old_value   = 'INACTIVE'
             iv_new_value   = |ANCHOR={ lv_anchor };DAYS={ lv_days }|
             iv_source      = 'INACTIVITY' ) = abap_true.
          COMMIT WORK AND WAIT.
          add_log(
            iv_level = 'S'
            iv_text  = |Closed inactivity case for { is_user-bname }| ).
        ELSE.
          ROLLBACK WORK.
          add_log(
            iv_level = 'E'
            iv_text  = |Failed to close inactivity case for { is_user-bname }| ).
        ENDIF.
      ENDIF.
      RETURN.
    ENDIF.

    IF is_user-uflag <> 0.
      IF ls_case-status = 'LOCKED' OR ls_case-status = 'EXT_LOCK'.
        RETURN.
      ENDIF.

      IF mv_simulation = abap_true.
        add_log(
          iv_level = 'S'
          iv_text  = |Would reconcile existing lock for { is_user-bname }| ).
        RETURN.
      ENDIF.

      DATA(lv_lock_recovery) = xsdbool( ls_case-status = 'LOCKING' ).
      ls_case-status = COND #(
        WHEN lv_lock_recovery = abap_true THEN 'LOCKED'
        ELSE 'EXT_LOCK' ).
      ls_case-last_error = COND #(
        WHEN lv_lock_recovery = abap_true THEN ''
        ELSE |Existing USR02-UFLAG={ is_user-uflag }| ).
      ls_case-changed_by = sy-uname.
      GET TIME STAMP FIELD ls_case-changed_at.
      IF lv_lock_recovery = abap_true AND ls_case-lock_at IS INITIAL.
        ls_case-lock_at = ls_case-changed_at.
      ENDIF.
      MODIFY ziam_ctrl_case FROM @ls_case.
      DATA(lv_existing_action) = COND char20(
        WHEN lv_lock_recovery = abap_true THEN 'INA_LOCK_RECOVER'
        ELSE 'INA_EXT_LOCK' ).
      IF sy-subrc = 0 AND
         write_audit(
           iv_action      = lv_existing_action
           iv_target_user = is_user-bname
           iv_new_value   = |STATUS={ ls_case-status };UFLAG={ is_user-uflag }|
           iv_source      = 'INACTIVITY' ) = abap_true.
        COMMIT WORK AND WAIT.
      ELSE.
        ROLLBACK WORK.
      ENDIF.
      RETURN.
    ENDIF.

    IF lv_days < iv_lock_at.
      IF ls_case-last_warn = iv_keydate.
        add_log(
          iv_level = 'I'
          iv_text  = |Warning already sent today to { is_user-bname }| ).
        RETURN.
      ENDIF.

      IF mv_simulation = abap_true.
        add_log(
          iv_level = 'S'
          iv_text  = |Would warn { is_user-bname }: inactive { lv_days } days| ).
        RETURN.
      ENDIF.

      resolve_email(
        EXPORTING
          iv_bname   = is_user-bname
        IMPORTING
          ev_email   = DATA(lv_email)
          ev_ok      = DATA(lv_email_ok)
          ev_message = DATA(lv_email_message) ).

      IF lv_email_ok = abap_false.
        ls_case-status = 'NO_MAIL'.
        ls_case-last_error = lv_email_message.
        ls_case-retry_count = ls_case-retry_count + 1.
        ls_case-changed_by = sy-uname.
        GET TIME STAMP FIELD ls_case-changed_at.
        MODIFY ziam_ctrl_case FROM @ls_case.
        IF sy-subrc = 0 AND
           write_audit(
             iv_action      = 'INA_WARN_ERR'
             iv_target_user = is_user-bname
             iv_new_value   = |DAYS={ lv_days };RESULT={ lv_email_message }|
             iv_source      = 'INACTIVITY' ) = abap_true.
          COMMIT WORK AND WAIT.
        ELSE.
          ROLLBACK WORK.
        ENDIF.
        add_log(
          iv_level = 'E'
          iv_text  = |Cannot warn { is_user-bname }: { lv_email_message }| ).
        RETURN.
      ENDIF.

      DATA lv_lockdate TYPE sy-datum.
      lv_lockdate = lv_anchor + iv_lock_at.
      send_warning(
        EXPORTING
          iv_bname    = is_user-bname
          iv_email    = lv_email
          iv_days     = lv_days
          iv_lockdate = lv_lockdate
        IMPORTING
          ev_ok       = DATA(lv_mail_ok)
          ev_message  = DATA(lv_mail_message) ).

      IF lv_mail_ok = abap_true.
        ls_case-status = 'WARNED'.
        ls_case-last_warn = iv_keydate.
        ls_case-warn_count = ls_case-warn_count + 1.
        ls_case-mail_addr = lv_email.
        CLEAR ls_case-last_error.
      ELSE.
        ls_case-status = 'MAIL_ERR'.
        ls_case-retry_count = ls_case-retry_count + 1.
        ls_case-last_error = lv_mail_message.
      ENDIF.
      ls_case-changed_by = sy-uname.
      GET TIME STAMP FIELD ls_case-changed_at.

      MODIFY ziam_ctrl_case FROM @ls_case.
      DATA(lv_warn_action) = COND char20(
        WHEN lv_mail_ok = abap_true THEN 'INA_WARN_OK'
        ELSE 'INA_WARN_ERR' ).
      IF sy-subrc = 0 AND
         write_audit(
           iv_action      = lv_warn_action
           iv_target_user = is_user-bname
           iv_new_value   = |DAYS={ lv_days };COUNT={ ls_case-warn_count };RESULT={ lv_mail_message }|
           iv_source      = 'INACTIVITY' ) = abap_true.
        COMMIT WORK AND WAIT.
      ELSE.
        ROLLBACK WORK.
        lv_mail_ok = abap_false.
        lv_mail_message = 'Persistence or audit failure'.
      ENDIF.

      add_log(
        iv_level = COND #( WHEN lv_mail_ok = abap_true THEN 'S' ELSE 'E' )
        iv_text  = |Warning { is_user-bname }: { lv_mail_message }| ).
      RETURN.
    ENDIF.

    IF mv_simulation = abap_true.
      add_log(
        iv_level = 'S'
        iv_text  = |Would lock { is_user-bname }: inactive { lv_days } days| ).
      RETURN.
    ENDIF.

    SELECT SINGLE *
      FROM usr02
      WHERE bname = @is_user-bname
      INTO @DATA(ls_current).
    IF sy-subrc <> 0 OR ls_current-uflag <> 0.
      add_log(
        iv_level = 'W'
        iv_text  = |Lock skipped after recheck for { is_user-bname }| ).
      RETURN.
    ENDIF.

    DATA(lv_current_anchor) = COND sy-datum(
      WHEN ls_current-trdat IS NOT INITIAL THEN ls_current-trdat
      ELSE ls_current-erdat ).
    DATA(lv_current_days) = iv_keydate - lv_current_anchor.
    IF lv_current_anchor IS INITIAL OR lv_current_days < iv_lock_at.
      add_log(
        iv_level = 'W'
        iv_text  = |Lock skipped: { is_user-bname } logged in during scan| ).
      RETURN.
    ENDIF.

    ls_case-status = 'LOCKING'.
    ls_case-last_error = 'Lock operation started'.
    ls_case-changed_by = sy-uname.
    GET TIME STAMP FIELD ls_case-changed_at.
    MODIFY ziam_ctrl_case FROM @ls_case.
    IF sy-subrc <> 0 OR
       write_audit(
         iv_action      = 'INA_LOCK_BEGIN'
         iv_target_user = is_user-bname
         iv_old_value   = 'UNLOCKED'
         iv_new_value   = |DAYS={ lv_current_days }|
         iv_source      = 'INACTIVITY' ) = abap_false.
      ROLLBACK WORK.
      add_log(
        iv_level = 'E'
        iv_text  = |Lock not attempted because intent audit failed for { is_user-bname }| ).
      RETURN.
    ENDIF.
    COMMIT WORK AND WAIT.

    DATA lt_return TYPE tt_bapiret2.
    CALL FUNCTION 'BAPI_USER_LOCK'
      EXPORTING
        username = is_user-bname
      TABLES
        return   = lt_return.

    DATA(lv_lock_error) = has_bapi_error( lt_return ).
    DATA(lv_lock_message) = bapi_message( lt_return ).
    IF lv_lock_error = abap_true.
      ls_case-status = 'LOCK_ERR'.
      ls_case-retry_count = ls_case-retry_count + 1.
      ls_case-last_error = lv_lock_message.
      ls_case-changed_by = sy-uname.
      GET TIME STAMP FIELD ls_case-changed_at.
      MODIFY ziam_ctrl_case FROM @ls_case.
      IF sy-subrc = 0.
        write_audit(
          iv_action      = 'INA_LOCK_ERR'
          iv_target_user = is_user-bname
          iv_new_value   = |DAYS={ lv_current_days };RESULT={ lv_lock_message }|
          iv_source      = 'INACTIVITY' ).
        COMMIT WORK AND WAIT.
      ELSE.
        ROLLBACK WORK.
      ENDIF.
      add_log(
        iv_level = 'E'
        iv_text  = |Lock failed for { is_user-bname }: { lv_lock_message }| ).
      RETURN.
    ENDIF.

    DATA ls_locked TYPE bapislockd.
    CLEAR lt_return.
    CALL FUNCTION 'BAPI_USER_GET_DETAIL'
      EXPORTING
        username      = is_user-bname
        cache_results = space
      IMPORTING
        islocked      = ls_locked
      TABLES
        return        = lt_return.

    IF has_bapi_error( lt_return ) = abap_true OR
       ( ls_locked-local_lock <> 'L' AND ls_locked-glob_lock <> 'L' ).
      ls_case-status = 'LOCK_ERR'.
      ls_case-retry_count = ls_case-retry_count + 1.
      ls_case-last_error = 'Post-lock verification failed'.
      GET TIME STAMP FIELD ls_case-changed_at.
      MODIFY ziam_ctrl_case FROM @ls_case.
      write_audit(
        iv_action      = 'INA_LOCK_ERR'
        iv_target_user = is_user-bname
        iv_new_value   = ls_case-last_error
        iv_source      = 'INACTIVITY' ).
      COMMIT WORK AND WAIT.
      add_log(
        iv_level = 'E'
        iv_text  = |Post-lock verification failed for { is_user-bname }| ).
      RETURN.
    ENDIF.

    cl_sal_write_event=>write_user_changes(
      id_user   = is_user-bname
      id_locked = abap_true ).

    ls_case-status = 'LOCKED'.
    CLEAR ls_case-last_error.
    ls_case-changed_by = sy-uname.
    GET TIME STAMP FIELD ls_case-lock_at.
    ls_case-changed_at = ls_case-lock_at.
    MODIFY ziam_ctrl_case FROM @ls_case.
    IF sy-subrc = 0 AND
       write_audit(
         iv_action      = 'INA_LOCK_OK'
         iv_target_user = is_user-bname
         iv_old_value   = 'LOCKING'
         iv_new_value   = |LOCKED;DAYS={ lv_current_days }|
         iv_source      = 'INACTIVITY' ) = abap_true.
      COMMIT WORK AND WAIT.
      add_log(
        iv_level = 'S'
        iv_text  = |Locked { is_user-bname } after { lv_current_days } inactive days| ).
    ELSE.
      ROLLBACK WORK.
      add_log(
        iv_level = 'E'
        iv_text  = |Account { is_user-bname } is locked, but final Z-audit persistence failed| ).
    ENDIF.
  ENDMETHOD.

  METHOD resolve_email.
    DATA ls_address TYPE bapiaddr3.
    DATA lt_return TYPE tt_bapiret2.

    CLEAR: ev_email, ev_ok, ev_message.
    CALL FUNCTION 'BAPI_USER_GET_DETAIL'
      EXPORTING
        username      = iv_bname
        cache_results = space
      IMPORTING
        address       = ls_address
      TABLES
        return        = lt_return.

    IF has_bapi_error( lt_return ) = abap_true.
      ev_message = bapi_message( lt_return ).
      RETURN.
    ENDIF.
    IF ls_address-e_mail IS INITIAL.
      ev_message = 'No email address maintained'.
      RETURN.
    ENDIF.

    ev_email = ls_address-e_mail.
    ev_ok = abap_true.
    ev_message = 'Email resolved'.
  ENDMETHOD.

  METHOD send_warning.
    CLEAR: ev_ok, ev_message.
    TRY.
        DATA lt_text TYPE bcsy_text.
        DATA(lv_lockdate_text) = |{ iv_lockdate DATE = USER }|.
        DATA(lv_webgui_url) = 'https://s40lp1.ucc.cit.tum.de/sap/bc/gui/sap/its/webgui?sap-client=324&amp;sap-language=EN'.
        APPEND '<html><body style="margin:0;background:#f4f7fb;font-family:Arial,sans-serif;">' TO lt_text.
        APPEND '<table width="100%" cellpadding="0" cellspacing="0" style="background:#f4f7fb;padding:24px 0;">' TO lt_text.
        APPEND '<tr><td align="center">' TO lt_text.
        APPEND '<table width="640" cellpadding="0" cellspacing="0" style="background:#ffffff;border-radius:14px;overflow:hidden;">' TO lt_text.
        APPEND '<tr><td style="background:#0f4c81;color:#ffffff;padding:22px 28px;">' TO lt_text.
        APPEND '<div style="font-size:20px;font-weight:bold;">SAP Account Inactivity Warning</div>' TO lt_text.
        APPEND '<div style="font-size:13px;margin-top:6px;opacity:.9;">Action required to keep your account active</div>' TO lt_text.
        APPEND '</td></tr>' TO lt_text.
        APPEND '<tr><td style="padding:28px;color:#1f2937;font-size:14px;line-height:1.55;">' TO lt_text.
        APPEND |<p style="margin:0 0 16px;">Hello <b>{ iv_bname }</b>,</p>| TO lt_text.
        APPEND |<p>Your SAP account has been inactive for <b>{ iv_days } days</b>.</p>| TO lt_text.
        APPEND '<table width="100%" cellpadding="0" cellspacing="0" style="margin:18px 0;border-collapse:collapse;">' TO lt_text.
        APPEND '<tr>' TO lt_text.
        APPEND '<td style="background:#fff7ed;border:1px solid #fed7aa;border-radius:10px;padding:16px;">' TO lt_text.
        APPEND |<div style="color:#9a3412;font-size:13px;font-weight:bold;">Lock deadline</div>| TO lt_text.
        APPEND |<div style="font-size:24px;font-weight:bold;color:#c2410c;margin-top:4px;">{ lv_lockdate_text }</div>| TO lt_text.
        APPEND '<div style="font-size:13px;color:#7c2d12;margin-top:6px;">Please log in before this date.</div>' TO lt_text.
        APPEND '</td>' TO lt_text.
        APPEND '</tr>' TO lt_text.
        APPEND '</table>' TO lt_text.
        APPEND '<p>If no login is detected before the deadline, the account will be locked automatically.</p>' TO lt_text.
        APPEND '<div style="margin:24px 0;text-align:center;">' TO lt_text.
        APPEND |<a href="{ lv_webgui_url }" style="display:inline-block;background:#16a34a;color:#ffffff;| TO lt_text.
        APPEND 'padding:12px 22px;border-radius:999px;font-weight:bold;text-decoration:none;">Log in to SAP WebGUI</a>' TO lt_text.
        APPEND '</div>' TO lt_text.
        APPEND |<p style="font-size:12px;color:#6b7280;">WebGUI link: <a href="{ lv_webgui_url }">Open SAP WebGUI</a></p>| TO lt_text.
        APPEND '<p style="font-size:12px;color:#6b7280;margin-top:22px;">' TO lt_text.
        APPEND 'This is an automated message from IAM Access Control. If you believe this is incorrect, contact your Basis administrator.' TO lt_text.
        APPEND '</p>' TO lt_text.
        APPEND '</td></tr>' TO lt_text.
        APPEND '</table>' TO lt_text.
        APPEND '</td></tr>' TO lt_text.
        APPEND '</table>' TO lt_text.
        APPEND '</body></html>' TO lt_text.

        DATA(lo_request) = cl_bcs=>create_persistent( ).
        DATA(lo_document) = cl_document_bcs=>create_document(
          i_type    = 'HTM'
          i_text    = lt_text
          i_subject = 'SAP account inactivity warning' ).
        lo_request->set_document( lo_document ).
        lo_request->set_sender(
          cl_sapuser_bcs=>create( i_user = sy-uname ) ).
        lo_request->add_recipient(
          cl_cam_address_bcs=>create_internet_address(
            i_address_string = iv_email ) ).
        lo_request->set_send_immediately( abap_true ).
        ev_ok = lo_request->send( i_with_error_screen = abap_false ).
        IF ev_ok = abap_true.
          ev_message = 'Mail queued'.
        ELSE.
          ev_message = 'CL_BCS returned not sent'.
        ENDIF.
      CATCH cx_bcs INTO DATA(lx_bcs).
        ev_message = lx_bcs->get_text( ).
    ENDTRY.
  ENDMETHOD.

  METHOD has_bapi_error.
    rv_error = abap_false.
    LOOP AT it_return TRANSPORTING NO FIELDS
      WHERE type = 'E' OR type = 'A' OR type = 'X'.
      rv_error = abap_true.
      RETURN.
    ENDLOOP.
  ENDMETHOD.

  METHOD bapi_message.
    CLEAR rv_message.
    LOOP AT it_return INTO DATA(ls_return).
      IF ls_return-message IS INITIAL.
        CONTINUE.
      ENDIF.
      IF rv_message IS INITIAL.
        rv_message = ls_return-message.
      ELSE.
        rv_message = |{ rv_message }; { ls_return-message }|.
      ENDIF.
      IF strlen( rv_message ) >= 240.
        EXIT.
      ENDIF.
    ENDLOOP.
    IF rv_message IS INITIAL.
      rv_message = 'No BAPI error message'.
    ENDIF.
  ENDMETHOD.

  METHOD get_roles.
    DATA lt_return TYPE tt_bapiret2.
    CLEAR: et_roles, ev_ok, ev_message.

    CALL FUNCTION 'BAPI_USER_GET_DETAIL'
      EXPORTING
        username      = iv_user
        cache_results = space
      TABLES
        activitygroups = et_roles
        return         = lt_return.

    IF has_bapi_error( lt_return ) = abap_true.
      ev_message = bapi_message( lt_return ).
      RETURN.
    ENDIF.

    ev_ok = abap_true.
    ev_message = bapi_message( lt_return ).
  ENDMETHOD.

  METHOD verify_unrelated_roles.
    rv_ok = abap_true.
    LOOP AT it_before INTO DATA(ls_before)
      WHERE agr_name <> iv_target.
      READ TABLE it_after TRANSPORTING NO FIELDS
        WITH KEY agr_name = ls_before-agr_name
                 from_dat = ls_before-from_dat
                 to_dat   = ls_before-to_dat
                 org_flag = ls_before-org_flag.
      IF sy-subrc <> 0.
        rv_ok = abap_false.
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD assign_roles.
    DATA lt_return TYPE tt_bapiret2.
    DATA lt_after TYPE tt_bapiagr.
    DATA lt_desired TYPE tt_bapiagr.
    DATA lv_read_ok TYPE abap_bool.
    DATA lv_read_message TYPE char255.

    CLEAR: ev_ok, ev_message.
    lt_desired = it_desired.
    CALL FUNCTION 'BAPI_USER_ACTGROUPS_ASSIGN'
      EXPORTING
        username       = iv_user
      TABLES
        activitygroups = lt_desired
        return         = lt_return.

    DATA(lv_bapi_error) = has_bapi_error( lt_return ).
    DATA(lv_bapi_message) = bapi_message( lt_return ).

    get_roles(
      EXPORTING
        iv_user    = iv_user
      IMPORTING
        et_roles   = lt_after
        ev_ok      = lv_read_ok
        ev_message = lv_read_message ).
    IF lv_read_ok = abap_false.
      ev_message = |Read-after-write failed: { lv_read_message }|.
      RETURN.
    ENDIF.

    IF iv_expect_present = abap_true.
      IF iv_expect_from IS INITIAL AND iv_expect_to IS INITIAL.
        READ TABLE lt_after TRANSPORTING NO FIELDS
          WITH KEY agr_name = iv_target.
      ELSE.
        READ TABLE lt_after TRANSPORTING NO FIELDS
          WITH KEY agr_name = iv_target
                   from_dat = iv_expect_from
                   to_dat   = iv_expect_to.
      ENDIF.
      IF sy-subrc <> 0.
        ev_message = |Target role state not applied. { lv_bapi_message }|.
        RETURN.
      ENDIF.
    ELSE.
      IF iv_expect_from IS INITIAL AND iv_expect_to IS INITIAL.
        READ TABLE lt_after TRANSPORTING NO FIELDS
          WITH KEY agr_name = iv_target.
      ELSE.
        READ TABLE lt_after TRANSPORTING NO FIELDS
          WITH KEY agr_name = iv_target
                   from_dat = iv_expect_from
                   to_dat   = iv_expect_to.
      ENDIF.
      IF sy-subrc = 0.
        ev_message = |Target role fingerprint still exists. { lv_bapi_message }|.
        RETURN.
      ENDIF.
    ENDIF.

    IF verify_unrelated_roles(
         it_before = it_before
         it_after  = lt_after
         iv_target = iv_target ) = abap_false.
      ev_message = 'Unrelated role fingerprint changed'.
      RETURN.
    ENDIF.

    ev_ok = abap_true.
    IF lv_bapi_error = abap_true.
      ev_message = |State verified despite BAPI return: { lv_bapi_message }|.
    ELSE.
      ev_message = 'Role state verified'.
    ENDIF.
  ENDMETHOD.







  METHOD close_grant.
    IF acquire_user_lock( cs_grant-target_user ) = abap_false.
      add_log(
        iv_level = 'W'
        iv_text  = |User { cs_grant-target_user } is busy; revoke was not processed| ).
      RETURN.
    ENDIF.

    SELECT SINGLE *
      FROM ziam_ff_grant
      WHERE grant_id = @cs_grant-grant_id
      INTO @DATA(ls_current_grant).
    IF sy-subrc = 0.
      cs_grant = ls_current_grant.
      close_grant_locked(
        EXPORTING
          iv_expired = iv_expired
          iv_reason  = iv_reason
        CHANGING
          cs_grant   = cs_grant ).
    ELSE.
      add_log(
        iv_level = 'E'
        iv_text  = |Grant { cs_grant-grant_id } no longer exists| ).
    ENDIF.

    release_user_lock( cs_grant-target_user ).
  ENDMETHOD.

  METHOD close_grant_locked.
    IF cs_grant-status <> 'ACTIVE' AND cs_grant-status <> 'REVOKE_ERR'.
      add_log(
        iv_level = 'I'
        iv_text  = |Grant { cs_grant-grant_id } is no longer revocable| ).
      RETURN.
    ENDIF.

    DATA lv_now TYPE timestampl.
    DATA lv_process_until TYPE timestampl.
    GET TIME STAMP FIELD lv_now.
    TRY.
        lv_process_until = cl_abap_tstmp=>add(
          tstmp = lv_now
          secs  = 300 ).
        DATA(lv_token) = cl_system_uuid=>create_uuid_c32_static( ).
      CATCH cx_parameter_invalid INTO DATA(lx_time).
        add_log( iv_level = 'E' iv_text = lx_time->get_text( ) ).
        RETURN.
      CATCH cx_uuid_error INTO DATA(lx_uuid).
        add_log( iv_level = 'E' iv_text = lx_uuid->get_text( ) ).
        RETURN.
    ENDTRY.

    DATA(lv_old_status) = cs_grant-status.
    DATA(lv_new_version) = cs_grant-row_version + 1.
    UPDATE ziam_ff_grant
      SET status        = 'REVOKING',
          process_token = @lv_token,
          process_until = @lv_process_until,
          row_version   = @lv_new_version,
          changed_by    = @sy-uname,
          changed_at    = @lv_now
      WHERE grant_id   = @cs_grant-grant_id
        AND row_version = @cs_grant-row_version.
    IF sy-dbcnt <> 1.
      ROLLBACK WORK.
      add_log( iv_level = 'E' iv_text = |Concurrent revoke for { cs_grant-grant_id }| ).
      RETURN.
    ENDIF.
    COMMIT WORK AND WAIT.

    cs_grant-status = 'REVOKING'.
    cs_grant-process_token = lv_token.
    cs_grant-process_until = lv_process_until.
    cs_grant-row_version = lv_new_version.
    cs_grant-changed_by = sy-uname.
    cs_grant-changed_at = lv_now.

    DATA lv_revoke_ok TYPE abap_bool VALUE abap_true.
    DATA lv_revoke_message TYPE char255.

    IF cs_grant-role_added = abap_false.
      lv_revoke_message = 'No physical revoke: baseline or overlapping role preserved'.
    ELSE.
      SELECT *
        FROM ziam_ff_grant
        WHERE target_user = @cs_grant-target_user
          AND agr_name    = @cs_grant-agr_name
          AND grant_id   <> @cs_grant-grant_id
          AND status      = 'ACTIVE'
          AND end_at      > @lv_now
        INTO TABLE @DATA(lt_other).
      SORT lt_other BY end_at DESCENDING.
      READ TABLE lt_other INTO DATA(ls_other) INDEX 1.

      IF sy-subrc = 0.
        DATA lt_current TYPE tt_bapiagr.
        DATA lv_current_ok TYPE abap_bool.
        DATA lv_current_message TYPE char255.
        get_roles(
          EXPORTING
            iv_user    = cs_grant-target_user
          IMPORTING
            et_roles   = lt_current
            ev_ok      = lv_current_ok
            ev_message = lv_current_message ).
        IF lv_current_ok = abap_false.
          lv_revoke_ok = abap_false.
          lv_revoke_message = lv_current_message.
        ELSE.
          READ TABLE lt_current INTO DATA(ls_current_role)
            WITH KEY agr_name = cs_grant-agr_name
                     from_dat = cs_grant-role_from
                     to_dat   = cs_grant-role_to.
          IF sy-subrc <> 0.
            lv_revoke_ok = abap_false.
            lv_revoke_message = 'Managed role missing during ownership transfer'.
          ELSE.
            ls_other-role_added = abap_true.
            ls_other-role_from = ls_current_role-from_dat.
            ls_other-role_to = ls_current_role-to_dat.
            ls_other-row_version = ls_other-row_version + 1.
            ls_other-changed_by = sy-uname.
            ls_other-changed_at = lv_now.
            MODIFY ziam_ff_grant FROM @ls_other.
            IF sy-subrc = 0.
              lv_revoke_message = |Role retained for overlapping grant { ls_other-grant_id }|.
            ELSE.
              lv_revoke_ok = abap_false.
              lv_revoke_message = 'Failed to transfer managed role ownership'.
            ENDIF.
          ENDIF.
        ENDIF.
      ELSE.
        DATA lt_before TYPE tt_bapiagr.
        DATA lv_roles_ok TYPE abap_bool.
        DATA lv_roles_message TYPE char255.
        get_roles(
          EXPORTING
            iv_user    = cs_grant-target_user
          IMPORTING
            et_roles   = lt_before
            ev_ok      = lv_roles_ok
            ev_message = lv_roles_message ).
        IF lv_roles_ok = abap_false.
          lv_revoke_ok = abap_false.
          lv_revoke_message = lv_roles_message.
        ELSE.
          READ TABLE lt_before INTO DATA(ls_managed_role)
            WITH KEY agr_name = cs_grant-agr_name
                     from_dat = cs_grant-role_from
                     to_dat   = cs_grant-role_to.
          IF sy-subrc <> 0.
            READ TABLE lt_before TRANSPORTING NO FIELDS
              WITH KEY agr_name = cs_grant-agr_name.
            IF sy-subrc = 0.
              lv_revoke_ok = abap_false.
              lv_revoke_message = 'DRIFT: managed role validity changed; manual review required'.
            ELSE.
              lv_revoke_message = 'Managed role was already absent'.
            ENDIF.
          ELSE.
            DATA lt_desired TYPE tt_bapiagr.
            lt_desired = lt_before.
            DELETE lt_desired
              WHERE agr_name = cs_grant-agr_name
                AND from_dat = cs_grant-role_from
                AND to_dat   = cs_grant-role_to.
            assign_roles(
              EXPORTING
                iv_user           = cs_grant-target_user
                iv_target         = cs_grant-agr_name
                it_before         = lt_before
                it_desired        = lt_desired
                iv_expect_present = abap_false
                iv_expect_from    = cs_grant-role_from
                iv_expect_to      = cs_grant-role_to
              IMPORTING
                ev_ok             = lv_revoke_ok
                ev_message        = lv_revoke_message ).
          ENDIF.
        ENDIF.
      ENDIF.
    ENDIF.

    GET TIME STAMP FIELD cs_grant-changed_at.
    cs_grant-changed_by = sy-uname.
    cs_grant-last_message = COND #(
      WHEN iv_reason IS INITIAL THEN lv_revoke_message
      ELSE |{ lv_revoke_message }; { iv_reason }| ).
    CLEAR: cs_grant-process_token, cs_grant-process_until.
    cs_grant-row_version = cs_grant-row_version + 1.

    IF lv_revoke_ok = abap_true.
      cs_grant-status = COND #(
        WHEN iv_expired = abap_true THEN 'EXPIRED'
        ELSE 'REVOKED' ).
      cs_grant-revoked_by = sy-uname.
      cs_grant-revoked_at = cs_grant-changed_at.
    ELSEIF lv_revoke_message CP 'DRIFT:*'.
      cs_grant-status = 'REVIEW_REQ'.
      cs_grant-retry_count = cs_grant-retry_count + 1.
    ELSE.
      cs_grant-status = 'REVOKE_ERR'.
      cs_grant-retry_count = cs_grant-retry_count + 1.
    ENDIF.

    MODIFY ziam_ff_grant FROM @cs_grant.
    DATA(lv_revoke_saved) = xsdbool( sy-subrc = 0 ).
    DATA(lv_action) = COND char20(
      WHEN lv_revoke_ok = abap_true THEN 'FF_REVOKE_OK'
      ELSE 'FF_REVOKE_ERR' ).
    write_sal(
      iv_subid  = COND #( WHEN lv_revoke_ok = abap_true THEN 'Y' ELSE 'Z' )
      iv_user   = cs_grant-target_user
      iv_role   = cs_grant-agr_name
      iv_req_id = cs_grant-grant_id
      iv_result = lv_action ).
    IF lv_revoke_saved = abap_true AND
       write_audit(
         iv_action      = lv_action
         iv_target_user = cs_grant-target_user
         iv_old_value   = CONV char255( lv_old_status )
         iv_new_value   = |REQ={ cs_grant-grant_id };ROLE={ cs_grant-agr_name };STATUS={ cs_grant-status }|
         iv_source      = 'FIREFIGHT' ) = abap_true.
      COMMIT WORK AND WAIT.
    ELSE.
      ROLLBACK WORK.
      add_log(
        iv_level = 'E'
        iv_text  = |Role state changed for { cs_grant-grant_id }, but final Z-audit failed; recovery is required| ).
      RETURN.
    ENDIF.

    add_log(
      iv_level = COND #( WHEN lv_revoke_ok = abap_true THEN 'S' ELSE 'E' )
      iv_text  = |FF close { cs_grant-grant_id }: { lv_revoke_message }| ).
  ENDMETHOD.

  METHOD process_pending_ff_grants.
    DATA lv_now TYPE timestampl.
    GET TIME STAMP FIELD lv_now.

    SELECT *
      FROM ziam_ff_grant
      WHERE status = 'PENDING'
        AND start_at <= @lv_now
      INTO TABLE @DATA(lt_pending).

    add_log(
      iv_level = 'I'
      iv_text  = |Firefighter pending candidates={ lines( lt_pending ) }| ).

    LOOP AT lt_pending INTO DATA(ls_pending).
      IF mv_simulation = abap_true.
        add_log(
          iv_level = 'S'
          iv_text  = |Would grant FF { ls_pending-grant_id } for { ls_pending-target_user }/{ ls_pending-agr_name }| ).
        CONTINUE.
      ENDIF.

      IF acquire_user_lock( ls_pending-target_user ) = abap_false.
        add_log(
          iv_level = 'W'
          iv_text  = |User { ls_pending-target_user } is busy; FF grant was deferred| ).
        CONTINUE.
      ENDIF.

      SELECT SINGLE *
        FROM ziam_ff_grant
        WHERE grant_id    = @ls_pending-grant_id
          AND status      = 'PENDING'
          AND row_version = @ls_pending-row_version
        INTO @ls_pending.
      IF sy-subrc <> 0.
        release_user_lock( ls_pending-target_user ).
        CONTINUE.
      ENDIF.

      "No role is granted after the approved time-box has already elapsed.
      IF ls_pending-end_at <= lv_now.
        ls_pending-status = 'EXPIRED'.
        ls_pending-last_message = 'Expired before background grant processing'.
        ls_pending-row_version = ls_pending-row_version + 1.
        ls_pending-changed_by = sy-uname.
        ls_pending-changed_at = lv_now.
        MODIFY ziam_ff_grant FROM @ls_pending.
        IF sy-subrc = 0 AND
           write_audit(
             iv_action      = 'FF_GRANT_SKIP'
             iv_target_user = ls_pending-target_user
             iv_old_value   = 'PENDING'
             iv_new_value   = |REQ={ ls_pending-grant_id };EXPIRED_BEFORE_PROCESSING|
             iv_source      = 'FIREFIGHT' ) = abap_true.
          COMMIT WORK AND WAIT.
        ELSE.
          ROLLBACK WORK.
        ENDIF.
        release_user_lock( ls_pending-target_user ).
        CONTINUE.
      ENDIF.

      DATA lv_process_until TYPE timestampl.
      DATA lv_token TYPE ziam_ff_grant-process_token.
      DATA lv_claim_version TYPE ziam_ff_grant-row_version.
      TRY.
          lv_process_until = cl_abap_tstmp=>add(
            tstmp = lv_now
            secs  = 300 ).
          lv_token = cl_system_uuid=>create_uuid_c32_static( ).
        CATCH cx_parameter_invalid INTO DATA(lx_pending_time).
          add_log( iv_level = 'E' iv_text = lx_pending_time->get_text( ) ).
          release_user_lock( ls_pending-target_user ).
          CONTINUE.
        CATCH cx_uuid_error INTO DATA(lx_pending_uuid).
          add_log( iv_level = 'E' iv_text = lx_pending_uuid->get_text( ) ).
          release_user_lock( ls_pending-target_user ).
          CONTINUE.
      ENDTRY.

      lv_claim_version = ls_pending-row_version + 1.

      UPDATE ziam_ff_grant
        SET status        = 'GRANTING',
            process_token = @lv_token,
            process_until = @lv_process_until,
            row_version   = @lv_claim_version,
            changed_by    = @sy-uname,
            changed_at    = @lv_now,
            last_message  = 'Background role assignment in progress'
        WHERE grant_id    = @ls_pending-grant_id
          AND status      = 'PENDING'
          AND row_version = @ls_pending-row_version.
      IF sy-dbcnt <> 1.
        ROLLBACK WORK.
        release_user_lock( ls_pending-target_user ).
        CONTINUE.
      ENDIF.
      COMMIT WORK AND WAIT.

      DATA lt_before TYPE tt_bapiagr.
      DATA lv_read_ok TYPE abap_bool.
      DATA lv_message TYPE char255.
      DATA lv_grant_ok TYPE abap_bool VALUE abap_false.
      get_roles(
        EXPORTING
          iv_user    = ls_pending-target_user
        IMPORTING
          et_roles   = lt_before
          ev_ok      = lv_read_ok
          ev_message = lv_message ).

      IF lv_read_ok = abap_true.
        READ TABLE lt_before TRANSPORTING NO FIELDS
          WITH KEY agr_name = ls_pending-agr_name.
        IF sy-subrc = 0.
          lv_message = 'Target role already exists; no temporary-role ownership was created'.
        ELSE.
          DATA(lt_desired) = lt_before.
          APPEND VALUE #( agr_name = ls_pending-agr_name
                          from_dat = sy-datum
                          to_dat   = '99991231' ) TO lt_desired.
          assign_roles(
            EXPORTING
              iv_user           = ls_pending-target_user
              iv_target         = ls_pending-agr_name
              it_before         = lt_before
              it_desired        = lt_desired
              iv_expect_present = abap_true
              iv_expect_from    = sy-datum
              iv_expect_to      = '99991231'
            IMPORTING
              ev_ok             = lv_grant_ok
              ev_message        = lv_message ).
        ENDIF.
      ENDIF.

      GET TIME STAMP FIELD lv_now.
      CLEAR: ls_pending-process_token, ls_pending-process_until.
      ls_pending-row_version = lv_claim_version + 1.
      ls_pending-changed_by = sy-uname.
      ls_pending-changed_at = lv_now.
      IF lv_grant_ok = abap_true.
        ls_pending-status = 'ACTIVE'.
        ls_pending-granted_at = lv_now.
        ls_pending-role_added = abap_true.
        ls_pending-role_from = sy-datum.
        ls_pending-role_to = '99991231'.
        ls_pending-last_message = 'Role granted by background job'.
      ELSE.
        ls_pending-status = 'GRANT_ERR'.
        ls_pending-retry_count = ls_pending-retry_count + 1.
        ls_pending-last_message = lv_message.
      ENDIF.
      MODIFY ziam_ff_grant FROM @ls_pending.

      DATA(lv_grant_action) = COND char20(
        WHEN lv_grant_ok = abap_true THEN 'FF_GRANT_OK'
        ELSE 'FF_GRANT_ERR' ).
      IF sy-subrc = 0 AND
         write_audit(
           iv_action      = lv_grant_action
           iv_target_user = ls_pending-target_user
           iv_old_value   = 'PENDING'
           iv_new_value   = |REQ={ ls_pending-grant_id };ROLE={ ls_pending-agr_name };STATUS={ ls_pending-status };{ ls_pending-last_message }|
           iv_source      = 'FIREFIGHT' ) = abap_true.
        COMMIT WORK AND WAIT.
      ELSE.
        ROLLBACK WORK.
      ENDIF.

      add_log(
        iv_level = COND #( WHEN lv_grant_ok = abap_true THEN 'S' ELSE 'E' )
        iv_text  = |FF grant { ls_pending-grant_id }: { ls_pending-last_message }| ).
      release_user_lock( ls_pending-target_user ).
    ENDLOOP.
  ENDMETHOD.

  METHOD recover_firefighter_work.
    DATA lv_now TYPE timestampl.
    GET TIME STAMP FIELD lv_now.

    SELECT *
      FROM ziam_ff_grant
      WHERE status = 'GRANTING'
        AND process_until <= @lv_now
      INTO TABLE @DATA(lt_granting).
    LOOP AT lt_granting INTO DATA(ls_granting).
      DATA(lv_recovery_user) = ls_granting-target_user.
      IF acquire_user_lock( lv_recovery_user ) = abap_false.
        CONTINUE.
      ENDIF.

      SELECT SINGLE *
        FROM ziam_ff_grant
        WHERE grant_id     = @ls_granting-grant_id
          AND status       = 'GRANTING'
          AND process_until <= @lv_now
        INTO @ls_granting.
      IF sy-subrc <> 0.
        release_user_lock( lv_recovery_user ).
        CONTINUE.
      ENDIF.

      DATA lt_roles TYPE tt_bapiagr.
      DATA lv_ok TYPE abap_bool.
      DATA lv_message TYPE char255.
      get_roles(
        EXPORTING
          iv_user    = ls_granting-target_user
        IMPORTING
          et_roles   = lt_roles
          ev_ok      = lv_ok
          ev_message = lv_message ).
      IF lv_ok = abap_true.
        IF ls_granting-role_added = abap_true.
          READ TABLE lt_roles TRANSPORTING NO FIELDS
            WITH KEY agr_name = ls_granting-agr_name
                     from_dat = ls_granting-role_from
                     to_dat   = ls_granting-role_to.
          lv_ok = xsdbool( sy-subrc = 0 ).
        ELSE.
          lv_ok = abap_false.
          LOOP AT lt_roles TRANSPORTING NO FIELDS
            WHERE agr_name = ls_granting-agr_name
              AND ( from_dat = '00000000' OR from_dat <= sy-datum )
              AND ( to_dat   = '00000000' OR to_dat   >= sy-datum ).
            lv_ok = abap_true.
            EXIT.
          ENDLOOP.
        ENDIF.
      ENDIF.

      CLEAR: ls_granting-process_token, ls_granting-process_until.
      ls_granting-row_version = ls_granting-row_version + 1.
      ls_granting-changed_by = sy-uname.
      GET TIME STAMP FIELD ls_granting-changed_at.
      IF lv_ok = abap_true.
        ls_granting-status = 'ACTIVE'.
        IF ls_granting-granted_at IS INITIAL.
          ls_granting-granted_at = ls_granting-changed_at.
        ENDIF.
        ls_granting-last_message = 'Recovered GRANTING state from actual role'.
      ELSE.
        ls_granting-status = 'GRANT_ERR'.
        ls_granting-retry_count = ls_granting-retry_count + 1.
        ls_granting-last_message = 'Stale GRANTING state; role not verified'.
      ENDIF.
      MODIFY ziam_ff_grant FROM @ls_granting.
      DATA(lv_recovery_action) = COND char20(
        WHEN lv_ok = abap_true THEN 'FF_RECOVER_OK'
        ELSE 'FF_RECOVER_ERR' ).
      IF sy-subrc = 0 AND
         write_audit(
           iv_action      = lv_recovery_action
           iv_target_user = ls_granting-target_user
           iv_old_value   = 'GRANTING'
           iv_new_value   = |REQ={ ls_granting-grant_id };STATUS={ ls_granting-status }|
           iv_source      = 'FIREFIGHT' ) = abap_true.
        write_sal(
          iv_subid  = COND #( WHEN lv_ok = abap_true THEN 'X' ELSE 'Z' )
          iv_user   = ls_granting-target_user
          iv_role   = ls_granting-agr_name
          iv_req_id = ls_granting-grant_id
          iv_result = lv_recovery_action ).
        COMMIT WORK AND WAIT.
      ELSE.
        ROLLBACK WORK.
      ENDIF.
      release_user_lock( lv_recovery_user ).
    ENDLOOP.

    SELECT *
      FROM ziam_ff_grant
      WHERE status = 'REVOKING'
        AND process_until <= @lv_now
      INTO TABLE @DATA(lt_revoking).
    LOOP AT lt_revoking INTO DATA(ls_revoking).
      IF acquire_user_lock( ls_revoking-target_user ) = abap_false.
        CONTINUE.
      ENDIF.
      DATA lv_initial_ts TYPE timestampl.
      UPDATE ziam_ff_grant
        SET status = 'REVOKE_ERR',
            process_token = '',
            process_until = @lv_initial_ts,
            changed_by = @sy-uname,
            changed_at = @lv_now
        WHERE grant_id = @ls_revoking-grant_id
          AND status = 'REVOKING'
          AND process_until <= @lv_now.
      IF sy-dbcnt = 1 AND
         write_audit(
           iv_action      = 'FF_REVOKE_RECOVER'
           iv_target_user = ls_revoking-target_user
           iv_old_value   = 'REVOKING'
           iv_new_value   = |REQ={ ls_revoking-grant_id };REVOKE_ERR|
           iv_source      = 'FIREFIGHT' ) = abap_true.
        COMMIT WORK AND WAIT.
      ELSE.
        ROLLBACK WORK.
      ENDIF.
      release_user_lock( ls_revoking-target_user ).
    ENDLOOP.
  ENDMETHOD.

  METHOD run_firefighter_expiry.
    IF check_auth( '16' ) = abap_false.
      RETURN.
    ENDIF.

    process_pending_ff_grants( ).

    IF mv_simulation = abap_false.
      recover_firefighter_work( ).
    ENDIF.

    DATA lv_now TYPE timestampl.
    GET TIME STAMP FIELD lv_now.
    SELECT *
      FROM ziam_ff_grant
      WHERE ( status = 'ACTIVE' AND end_at <= @lv_now )
         OR status = 'REVOKE_ERR'
      INTO TABLE @DATA(lt_expired).

    add_log(
      iv_level = 'I'
      iv_text  = |Firefighter expiry candidates={ lines( lt_expired ) }| ).
    LOOP AT lt_expired INTO DATA(ls_grant).
      IF mv_simulation = abap_true.
        add_log(
          iv_level = 'S'
          iv_text  = |Would expire FF grant { ls_grant-grant_id } for { ls_grant-target_user }/{ ls_grant-agr_name }| ).
      ELSE.
        close_grant(
          EXPORTING
            iv_expired = abap_true
          CHANGING
            cs_grant   = ls_grant ).
      ENDIF.
    ENDLOOP.
  ENDMETHOD.





ENDCLASS.
