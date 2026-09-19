METHOD checkSod.
  READ ENTITIES OF zi_iam_lreq_hdr IN LOCAL MODE
    ENTITY Request ALL FIELDS WITH CORRESPONDING #( keys )
    RESULT DATA(lt_request).
  READ ENTITIES OF zi_iam_lreq_hdr IN LOCAL MODE
    ENTITY Request BY \_Roles ALL FIELDS WITH CORRESPONDING #( keys )
    RESULT DATA(lt_role).

  LOOP AT lt_request INTO DATA(ls_request).
    DATA(lt_requested_roles) = VALUE zcl_iam_sod_request_checker=>tt_role(
      FOR ls_role IN lt_role WHERE ( ReqUuid = ls_request-ReqUuid )
      ( agr_name = ls_role-RoleName ) ).
    DATA(lt_conflicts) = zcl_iam_sod_request_checker=>check_role_set(
      iv_target_user     = ls_request-TargetUser
      it_requested_roles = lt_requested_roles
      iv_request_vs_existing = abap_true ).
    DELETE FROM ziam_lreq_sod2 WHERE request_uuid = @ls_request-ReqUuid.
    LOOP AT lt_conflicts INTO DATA(ls_conflict).
      INSERT ziam_lreq_sod2 FROM @( VALUE #(
        request_uuid     = ls_request-ReqUuid
        rule_id          = ls_conflict-rule_id
        role_1           = ls_conflict-role_1
        role_2           = ls_conflict-role_2
        rule_name        = ls_conflict-rule_name
        risk_level       = ls_conflict-risk_level
        is_exempt        = ls_conflict-is_exempt
        exempt_reason    = ls_conflict-exempt_reason
        suggested_action = ls_conflict-suggested_action
        is_locked        = ls_conflict-is_locked
        last_login       = ls_conflict-last_login ) ).
    ENDLOOP.
    DATA(lv_risk_score) = COND int4(
      WHEN line_exists( lt_conflicts[ risk_level = 'C' is_exempt = abap_false ] ) THEN 3
      WHEN line_exists( lt_conflicts[ risk_level = 'H' is_exempt = abap_false ] ) THEN 2
      WHEN line_exists( lt_conflicts[ risk_level = 'M' is_exempt = abap_false ] ) THEN 1
      ELSE 0 ).
    MODIFY ENTITIES OF zi_iam_lreq_hdr IN LOCAL MODE
      ENTITY Request UPDATE FIELDS ( RiskScore )
      WITH VALUE #( ( %tky = ls_request-%tky RiskScore = lv_risk_score ) ).
    result = VALUE #( BASE result FOR ls_conflict IN lt_conflicts (
      %tky = ls_request-%tky
      %param = CORRESPONDING #( ls_conflict MAPPING RuleId = rule_id RuleName = rule_name
        Role1 = role_1 Role2 = role_2 RiskLevel = risk_level IsExempt = is_exempt
        ExemptReason = exempt_reason SuggestedAction = suggested_action
        IsLocked = is_locked LastLogin = last_login ) ) ).
  ENDLOOP.
ENDMETHOD.

METHOD approve.
  READ ENTITIES OF zi_iam_lreq_hdr IN LOCAL MODE
    ENTITY Request ALL FIELDS WITH CORRESPONDING #( keys )
    RESULT DATA(lt_request).
  READ ENTITIES OF zi_iam_lreq_hdr IN LOCAL MODE
    ENTITY Request BY \_Roles ALL FIELDS WITH CORRESPONDING #( keys )
    RESULT DATA(lt_role).

  LOOP AT lt_request INTO DATA(ls_request).
    READ TABLE keys ASSIGNING FIELD-SYMBOL(<ls_key>) WITH KEY %tky = ls_request-%tky.
    DATA(lt_requested_roles_for_approve) = VALUE zcl_iam_sod_request_checker=>tt_role(
      FOR ls_requested_role IN lt_role WHERE ( ReqUuid = ls_request-ReqUuid )
      ( agr_name = ls_requested_role-RoleName ) ).
    DATA(lt_approve_conflicts) = zcl_iam_sod_request_checker=>check_role_set(
      iv_target_user     = ls_request-TargetUser
      it_requested_roles = lt_requested_roles_for_approve
      iv_request_vs_existing = abap_true ).
    DATA(lv_approve_risk) = COND int4(
      WHEN line_exists( lt_approve_conflicts[ risk_level = 'C' is_exempt = abap_false ] ) THEN 3
      WHEN line_exists( lt_approve_conflicts[ risk_level = 'H' is_exempt = abap_false ] ) THEN 2
      WHEN line_exists( lt_approve_conflicts[ risk_level = 'M' is_exempt = abap_false ] ) THEN 1
      ELSE 0 ).
    IF lv_approve_risk = 3 AND <ls_key>-%param-ApprovalReason IS INITIAL.
      APPEND VALUE #( %tky = ls_request-%tky ) TO failed-request.
      APPEND VALUE #( %tky = ls_request-%tky
        %msg = new_message( id = 'ZMSG_IAM07' number = '100'
                            severity = if_abap_behv_message=>severity-error ) ) TO reported-request.
      CONTINUE.
    ENDIF.

    IF ls_request-ReqType = 'F'.
      DATA(lt_firefighter_roles) = VALUE #( FOR ls_role IN lt_role
        WHERE ( ReqUuid = ls_request-ReqUuid AND RoleName IS NOT INITIAL ) ( ls_role ) ).
      IF lines( lt_firefighter_roles ) <> 1.
        APPEND VALUE #( %tky = ls_request-%tky ) TO failed-request.
        CONTINUE.
      ENDIF.
      DATA(ls_role) = lt_firefighter_roles[ 1 ].
      DATA(ls_grant_result) = zcl_iam_ff_service=>approve_request(
        iv_request_uuid   = ls_request-ReqUuid
        iv_target_user    = ls_request-TargetUser
        iv_emergency_role = ls_role-RoleName
        iv_duration_hours = ls_request-DurationHours
        iv_ticket_id      = ls_request-TicketId
        iv_reason         = ls_request-Reason
        iv_requester      = ls_request-RequestedBy
        iv_approver       = sy-uname ).
      IF ls_grant_result-ok = abap_false.
        APPEND VALUE #( %tky = ls_request-%tky ) TO failed-request.
        APPEND VALUE #( %tky = ls_request-%tky
          %msg = new_message( id = 'ZMSG_IAM07' number = '001' severity = if_abap_behv_message=>severity-error
                              v1 = ls_grant_result-message ) ) TO reported-request.
        CONTINUE.
      ENDIF.
    ENDIF.

    IF lv_approve_risk = 3.
      READ TABLE lt_approve_conflicts INTO DATA(ls_critical_conflict)
        WITH KEY risk_level = 'C' is_exempt = abap_false.
      zcl_iam_audit_logger=>log_action(
        iv_action_type   = 'SOD_CRIT_APPR'
        iv_target_user   = ls_request-TargetUser
        iv_performed_by  = sy-uname
        iv_new_value     = |RULE={ ls_critical_conflict-rule_id };RATIONALE={ <ls_key>-%param-ApprovalReason }|
        iv_source_module = 'LIFECYCLE' ).
    ENDIF.

    MODIFY ENTITIES OF zi_iam_lreq_hdr IN LOCAL MODE
      ENTITY Request UPDATE FIELDS ( RiskScore ApprovalReason )
      WITH VALUE #( ( %tky = ls_request-%tky RiskScore = lv_approve_risk
                       ApprovalReason = <ls_key>-%param-ApprovalReason ) ).
  ENDLOOP.
ENDMETHOD.

METHOD getApprovalRationale.
  READ ENTITIES OF zi_iam_lreq_hdr IN LOCAL MODE
    ENTITY Request ALL FIELDS WITH CORRESPONDING #( keys )
    RESULT DATA(lt_request).
  LOOP AT lt_request INTO DATA(ls_request).
    IF sy-uname <> ls_request-ApprovedBy.
      AUTHORITY-CHECK OBJECT 'ZIAM_REQ' ID 'ACTVT' FIELD '03'.
      IF sy-subrc <> 0.
        APPEND VALUE #( %tky = ls_request-%tky ) TO failed-request.
        CONTINUE.
      ENDIF.
    ENDIF.
    APPEND VALUE #( %tky = ls_request-%tky
      %param-ApprovalReason = ls_request-ApprovalReason ) TO result.
  ENDLOOP.
ENDMETHOD.
