CLASS zcl_iam_ff_service DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES:
      BEGIN OF ty_result,
        ok       TYPE abap_bool,
        message  TYPE char255,
        grant_id TYPE ziam_ff_grant-grant_id,
        start_at TYPE timestampl,
        end_at   TYPE timestampl,
      END OF ty_result.

    CLASS-METHODS approve_request
      IMPORTING
        iv_request_uuid   TYPE sysuuid_x16
        iv_target_user    TYPE xubname
        iv_emergency_role TYPE agr_name
        iv_duration_hours TYPE i
        iv_ticket_id      TYPE ziam_ff_grant-ticket_id
        iv_reason         TYPE ziam_ff_grant-reason
        iv_requester      TYPE xubname
        iv_approver       TYPE xubname
      RETURNING
        VALUE(rs_result) TYPE ty_result.

    "Shared validation used by draft/save/submit and approval paths.  The
    "allowlist is the source of truth for the maximum duration per role.
    CLASS-METHODS validate_request
      IMPORTING
        iv_emergency_role TYPE agr_name
        iv_duration_hours TYPE i
      RETURNING
        VALUE(rv_error) TYPE char255.

  PRIVATE SECTION.
    CLASS-METHODS write_audit
      IMPORTING iv_action TYPE char20 iv_target_user TYPE xubname iv_request_uuid TYPE sysuuid_x16 iv_new_value TYPE char255
      RETURNING VALUE(rv_ok) TYPE abap_bool.

ENDCLASS.


CLASS zcl_iam_ff_service IMPLEMENTATION.
  METHOD approve_request.
    DATA lv_error TYPE char255.
    DATA ls_grant TYPE ziam_ff_grant.
    DATA lv_start TYPE timestampl.
    DATA lv_end TYPE timestampl.

    rs_result-ok = abap_false.
    lv_error = validate_request( iv_emergency_role = iv_emergency_role iv_duration_hours = iv_duration_hours ).
    IF lv_error IS NOT INITIAL.
      rs_result-message = lv_error.
      RETURN.
    ENDIF.

    SELECT SINGLE grant_id FROM ziam_ff_grant
      WHERE request_uuid = @iv_request_uuid AND status IN ( 'PENDING', 'GRANTING', 'ACTIVE', 'REVOKE_ERR' )
      INTO @DATA(lv_existing_grant).
    IF sy-subrc = 0.
      rs_result-message = |A Firefighter grant is already queued or in progress for this request. Grant ID: { lv_existing_grant }. Check grant status or have an administrator resolve a stale grant.|.
      rs_result-grant_id = lv_existing_grant.
      RETURN.
    ENDIF.

    TRY.
        ls_grant-grant_id = cl_system_uuid=>create_uuid_c32_static( ).
      CATCH cx_uuid_error.
        rs_result-message = 'Unable to create Firefighter grant ID'.
        RETURN.
    ENDTRY.

    GET TIME STAMP FIELD lv_start.
    TRY.
        lv_end = cl_abap_tstmp=>add( tstmp = lv_start secs = CONV tzntstmpl( iv_duration_hours * 3600 ) ).
      CATCH cx_parameter_invalid.
        rs_result-message = 'Unable to calculate Firefighter expiry timestamp'.
        RETURN.
    ENDTRY.

    ls_grant-request_uuid   = iv_request_uuid.
    ls_grant-target_user    = iv_target_user.
    ls_grant-agr_name       = iv_emergency_role.
    ls_grant-requester      = iv_requester.
    ls_grant-approver       = iv_approver.
    ls_grant-ticket_id      = iv_ticket_id.
    ls_grant-reason         = iv_reason.
    ls_grant-duration_hours = iv_duration_hours.
    "RAP must not call a role-maintenance BAPI or asynchronous RFC.  It only
    "persists the approval decision.  Mode E claims PENDING grants after the
    "RAP LUW has committed and owns all BAPI/rollback handling.
    ls_grant-status         = 'PENDING'.
    ls_grant-start_at       = lv_start.
    ls_grant-end_at         = lv_end.
    ls_grant-requested_at   = lv_start.
    ls_grant-approved_at    = lv_start.
    ls_grant-process_until  = lv_start.
    ls_grant-row_version    = 1.
    ls_grant-changed_by     = sy-uname.
    ls_grant-changed_at     = lv_start.
    INSERT ziam_ff_grant FROM @ls_grant.
    IF sy-subrc <> 0.
      rs_result-message = 'Unable to create Firefighter grant record'.
      RETURN.
    ENDIF.

    IF write_audit(
         iv_action = 'FF_GRANT_PENDING' iv_target_user = iv_target_user iv_request_uuid = iv_request_uuid
         iv_new_value = |GRANT={ ls_grant-grant_id };ROLE={ iv_emergency_role };END={ lv_end }| ) = abap_false.
      DELETE FROM ziam_ff_grant WHERE grant_id = @ls_grant-grant_id.
      rs_result-message = 'Grant creation was cancelled because Z-audit logging failed'.
      RETURN.
    ENDIF.

    rs_result-ok = abap_true.
    rs_result-message = 'Firefighter grant queued for background processing'.
    rs_result-grant_id = ls_grant-grant_id.
    rs_result-start_at = lv_start.
    rs_result-end_at = lv_end.
  ENDMETHOD.

  METHOD validate_request.
    IF iv_duration_hours < 1 OR iv_duration_hours > 24.
      rv_error = 'Duration must be between 1 and 24 hours'.
      RETURN.
    ENDIF.
    SELECT SINGLE max_hours FROM ziam_ff_role
      WHERE agr_name = @iv_emergency_role AND is_active = 'X'
      INTO @DATA(lv_max_hours).
    IF sy-subrc <> 0.
      rv_error = 'Emergency role is not active in the Firefighter allowlist'.
      RETURN.
    ENDIF.
    IF lv_max_hours > 0 AND iv_duration_hours > lv_max_hours.
      rv_error = |Duration exceeds allowlist maximum of { lv_max_hours } hour(s)|.
    ENDIF.
  ENDMETHOD.

  METHOD write_audit.
    DATA ls_audit TYPE ziam_aud_log2.
    TRY.
        ls_audit-log_id = cl_system_uuid=>create_uuid_c32_static( ).
      CATCH cx_uuid_error.
        RETURN.
    ENDTRY.
    ls_audit-action_type = iv_action.
    ls_audit-target_user = iv_target_user.
    ls_audit-performed_by = sy-uname.
    ls_audit-new_value = |REQ={ iv_request_uuid };{ iv_new_value }|.
    ls_audit-source_module = 'FIREFIGHT'.
    GET TIME STAMP FIELD ls_audit-timestamp.
    INSERT ziam_aud_log2 FROM @ls_audit.
    rv_ok = xsdbool( sy-subrc = 0 ).
  ENDMETHOD.

ENDCLASS.
