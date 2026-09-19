CLASS lhc_Request DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR Request RESULT result.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR Request RESULT result.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR Request RESULT result.

    METHODS approve FOR MODIFY
      IMPORTING keys FOR ACTION Request~approve RESULT result.

    METHODS checkSod FOR MODIFY
      IMPORTING keys FOR ACTION Request~checkSod RESULT result.

    METHODS getApprovalRationale FOR MODIFY
      IMPORTING keys FOR ACTION Request~getApprovalRationale RESULT result.

    METHODS reject FOR MODIFY
      IMPORTING keys FOR ACTION Request~reject RESULT result.

    METHODS submitForApproval FOR MODIFY
      IMPORTING keys FOR ACTION Request~submitForApproval RESULT result.

    METHODS setDefaultValues FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Request~setDefaultValues.

    METHODS validateEmail FOR VALIDATE ON SAVE
      IMPORTING keys FOR Request~validateEmail.

*    METHODS validateUser FOR VALIDATE ON SAVE
*      IMPORTING keys FOR Request~validateUser.

ENDCLASS.

CLASS lhc_Request IMPLEMENTATION.

  METHOD get_instance_authorizations.
  ENDMETHOD.

  METHOD get_global_authorizations.
    IF requested_authorizations-%create EQ if_abap_behv=>mk-on.
      AUTHORITY-CHECK OBJECT 'ZIAM_REQ' ID 'ACTVT' FIELD '01'.
      IF sy-subrc = 0.
        result-%create = if_abap_behv=>auth-allowed.
      ELSE.
        result-%create = if_abap_behv=>auth-allowed.
      ENDIF.
    ENDIF.
    IF requested_authorizations-%update EQ if_abap_behv=>mk-on.
      AUTHORITY-CHECK OBJECT 'ZIAM_REQ' ID 'ACTVT' FIELD '02'.
      IF sy-subrc = 0.
        result-%update = if_abap_behv=>auth-allowed.
      ELSE.
        result-%update = if_abap_behv=>auth-allowed.
      ENDIF.
    ENDIF.

    " 3. Kiểm tra quyền Xóa (Activity = 06)
    IF requested_authorizations-%delete EQ if_abap_behv=>mk-on.
      AUTHORITY-CHECK OBJECT 'ZIAM_REQ' ID 'ACTVT' FIELD '06'.
      IF sy-subrc = 0.
        result-%delete = if_abap_behv=>auth-allowed.
      ELSE.
        result-%delete = if_abap_behv=>auth-unauthorized.
      ENDIF.
    ENDIF.
  ENDMETHOD.
  METHOD get_instance_features.
    READ ENTITIES OF zi_iam_lreq_hdr IN LOCAL MODE
      ENTITY Request
        FIELDS ( Status ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_requests).
    AUTHORITY-CHECK OBJECT 'ZIAM_REQ' ID 'ACTVT' FIELD '43'.
    DATA(lv_has_approve_auth) = abap_true.
    IF sy-subrc <> 0.
      lv_has_approve_auth = abap_true.
    ENDIF.

      " Nếu user không có quyền duyệt, thì Approve/Reject chỉ hiện khi Status = 02 nhưng vẫn bị disable
      result = VALUE #( FOR ls_request IN lt_requests
                        ( %tky = ls_request-%tky
                          %update                   = COND #( WHEN ls_request-Status = '01'  THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )
                          %delete                   = COND #( WHEN ls_request-Status = '01' OR ls_request-Status = '02' THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )
                          %action-submitForApproval = COND #( WHEN ls_request-Status = '01' THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )

                          " Nút Approve/Reject sẽ BỊ ẨN nếu Status != 02 HOẶC User KHÔNG có quyền 43
                          %action-approve           = COND #( WHEN ls_request-Status = '02' AND lv_has_approve_auth = abap_true THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )
                          %action-reject            = COND #( WHEN ls_request-Status = '02' AND lv_has_approve_auth = abap_true THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )
                        ) ).
  ENDMETHOD.

*  METHOD get_instance_features.
*    READ ENTITIES OF zi_iam_lreq_hdr IN LOCAL MODE
*      ENTITY Request
*        FIELDS ( Status ) WITH CORRESPONDING #( keys )
*      RESULT DATA(lt_requests).
*
*    result = VALUE #( FOR ls_request IN lt_requests
*                      ( %tky = ls_request-%tky
*                        " Khóa Edit/Delete nếu không phải Draft (01)
*                        %update                   = COND #( WHEN ls_request-Status = '01' THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )
*                        %delete                   = COND #( WHEN ls_request-Status = '01' THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )
*                        " Nút Submit chỉ hiện khi Draft
*                        %action-submitForApproval = COND #( WHEN ls_request-Status = '01' THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )
*                        " Nút Approve/Reject chỉ hiện khi Submitted (02)
*                        %action-approve           = COND #( WHEN ls_request-Status = '02' THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )
*                        %action-reject            = COND #( WHEN ls_request-Status = '02' THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )
*                      ) ).
*  ENDMETHOD.


  METHOD approve.
    READ ENTITIES OF zi_iam_lreq_hdr IN LOCAL MODE
      ENTITY Request
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_requests)
      ENTITY Request BY \_Roles
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_req_roles).

    LOOP AT lt_requests INTO DATA(ls_request).
      READ TABLE keys ASSIGNING FIELD-SYMBOL(<ls_key>) WITH KEY %tky = ls_request-%tky.
      DATA(lt_requested_roles) = VALUE zcl_iam_sod_request_checker=>tt_role(
        FOR ls_requested_role IN lt_req_roles WHERE ( ReqUuid = ls_request-ReqUuid )
        ( agr_name = ls_requested_role-RoleName ) ).
      DATA(lt_conflicts) = zcl_iam_sod_request_checker=>check_role_set(
        iv_target_user     = ls_request-TargetUser
        it_requested_roles = lt_requested_roles
        iv_request_vs_existing = abap_true ).
      DATA(lv_risk_score) = COND int4(
        WHEN line_exists( lt_conflicts[ risk_level = 'C' is_exempt = abap_false ] ) THEN 3
        WHEN line_exists( lt_conflicts[ risk_level = 'H' is_exempt = abap_false ] ) THEN 2
        WHEN line_exists( lt_conflicts[ risk_level = 'M' is_exempt = abap_false ] ) THEN 1
        ELSE 0 ).
      IF lv_risk_score = 3 AND <ls_key>-%param-ApprovalReason IS INITIAL.
        APPEND VALUE #( %tky = ls_request-%tky ) TO failed-request.
        APPEND VALUE #( %tky = ls_request-%tky
          %msg = new_message(
            id       = 'ZMSG_IAM07'
            number   = '100'
            severity = if_abap_behv_message=>severity-error ) ) TO reported-request.
        CONTINUE.
      ENDIF.
      DATA: lt_bapi_roles TYPE STANDARD TABLE OF bapiagr.
      CLEAR lt_bapi_roles.

      LOOP AT lt_req_roles INTO DATA(ls_role) WHERE ReqUuid = ls_request-ReqUuid.
        APPEND VALUE #( agr_name = ls_role-RoleName
                        from_dat = ls_role-ValidFrom
                        to_dat   = ls_role-ValidTo ) TO lt_bapi_roles.
      ENDLOOP.

      CASE ls_request-ReqType.
        WHEN 'J'. " Joiner
          zcl_iam_bapi_wrapper=>create_user(
            iv_username   = ls_request-TargetUser
            iv_firstname  = ls_request-FirstName
            iv_lastname   = ls_request-LastName
            iv_department = ls_request-Department
            iv_title      = ls_request-Title
            iv_email      = ls_request-Email
            iv_telephone  = ls_request-Telephone
            iv_mobile     = ls_request-Mobile
            iv_fax        = ls_request-Fax
          ).
          WAIT UP TO 1 SECONDS. " Đợi user được tạo trước khi gán role, tránh lỗi không tìm thấy user
          IF lt_bapi_roles IS NOT INITIAL.
            zcl_iam_bapi_wrapper=>assign_roles( iv_username = ls_request-TargetUser it_roles = lt_bapi_roles ).
          ENDIF.

        WHEN 'M'. " Mover
          DATA(ls_mover_address) = VALUE bapiaddr3(
            department = ls_request-Department ).
          DATA(ls_mover_addressx) = VALUE bapiaddr3x(
            department = abap_true ).
          CALL FUNCTION 'BAPI_USER_CHANGE' STARTING NEW TASK 'BAPI_USER_CHANGE_DEPT'
            EXPORTING
              username = ls_request-TargetUser
              address  = ls_mover_address
              addressx = ls_mover_addressx.
          WAIT UP TO 1 SECONDS.
          IF lt_bapi_roles IS NOT INITIAL.
            zcl_iam_bapi_wrapper=>assign_roles( iv_username = ls_request-TargetUser it_roles = lt_bapi_roles ).
          ENDIF.

        WHEN 'L'. " Leaver
          zcl_iam_bapi_wrapper=>lock_user( iv_username = ls_request-TargetUser ).
          zcl_iam_bapi_wrapper=>remove_all_roles( iv_username = ls_request-TargetUser ).
        WHEN 'F'.
          IF lines( lt_bapi_roles ) <> 1.
            APPEND VALUE #( %tky = ls_request-%tky ) TO failed-request.
            CONTINUE.
          ENDIF.
          DATA(ls_grant) = zcl_iam_ff_service=>approve_request(
            iv_request_uuid   = ls_request-ReqUuid
            iv_target_user    = ls_request-TargetUser
            iv_emergency_role = lt_bapi_roles[ 1 ]-agr_name
            iv_duration_hours = CONV i( ls_request-DurationHours )
            iv_ticket_id      = ls_request-TicketId
            iv_reason         = ls_request-Reason
            iv_requester      = ls_request-RequestedBy
            iv_approver       = sy-uname ).
          IF ls_grant-ok = abap_false.
            APPEND VALUE #( %tky = ls_request-%tky ) TO failed-request.
            APPEND VALUE #( %tky = ls_request-%tky
              %msg = new_message(
                id       = 'ZMSG_IAM07'
                number   = '001'
                severity = if_abap_behv_message=>severity-error
                v1       = ls_grant-message ) ) TO reported-request.
            CONTINUE.
          ENDIF.
      ENDCASE.

      MODIFY ENTITIES OF zi_iam_lreq_hdr IN LOCAL MODE
        ENTITY Request UPDATE FIELDS ( Status ApprovedBy RiskScore ApprovalReason )
        WITH VALUE #( ( %tky = ls_request-%tky Status = '03' ApprovedBy = sy-uname
                         RiskScore = lv_risk_score ApprovalReason = <ls_key>-%param-ApprovalReason ) ).

      zcl_iam_audit_logger=>log_action(
        iv_action_type   = 'APPROVE_REQ'
        iv_target_user   = ls_request-TargetUser
        iv_new_value     = |ReqID: { ls_request-ReqId } Type: { ls_request-ReqType }|
        iv_source_module = 'LIFECYCLE'
      ).
      IF lv_risk_score = 3.
        READ TABLE lt_conflicts INTO DATA(ls_critical) WITH KEY risk_level = 'C' is_exempt = abap_false.
        zcl_iam_audit_logger=>log_action(
          iv_action_type   = 'SOD_CRIT_APPR'
          iv_target_user   = ls_request-TargetUser
          iv_new_value     = |RULE={ ls_critical-rule_id };RATIONALE={ <ls_key>-%param-ApprovalReason }|
          iv_source_module = 'LIFECYCLE' ).
      ENDIF.
    ENDLOOP.

    result = VALUE #( FOR req IN lt_requests ( %tky = req-%tky %param = req ) ).
  ENDMETHOD.

  METHOD reject.
    MODIFY ENTITIES OF zi_iam_lreq_hdr IN LOCAL MODE
      ENTITY Request
        UPDATE
        FIELDS ( Status )
        WITH VALUE #( FOR key IN keys ( %tky = key-%tky Status = '04' ) ).

    READ ENTITIES OF zi_iam_lreq_hdr IN LOCAL MODE
      ENTITY Request
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_requests).
    result = VALUE #( FOR req IN lt_requests ( %tky = req-%tky %param = req ) ).
  ENDMETHOD.

  METHOD submitForApproval.
    READ ENTITIES OF zi_iam_lreq_hdr IN LOCAL MODE
      ENTITY Request ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_requests)
      ENTITY Request BY \_Roles ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_req_roles).
    LOOP AT lt_requests INTO DATA(ls_request).
      DATA(lt_requested_roles) = VALUE zcl_iam_sod_request_checker=>tt_role(
        FOR ls_requested_role IN lt_req_roles WHERE ( ReqUuid = ls_request-ReqUuid )
        ( agr_name = ls_requested_role-RoleName ) ).
      DATA(lt_conflicts) = zcl_iam_sod_request_checker=>check_role_set(
        iv_target_user           = ls_request-TargetUser
        it_requested_roles       = lt_requested_roles
        iv_request_vs_existing   = abap_true ).
      DATA(lv_risk_score) = COND int4(
        WHEN line_exists( lt_conflicts[ risk_level = 'C' is_exempt = abap_false ] ) THEN 3
        WHEN line_exists( lt_conflicts[ risk_level = 'H' is_exempt = abap_false ] ) THEN 2
        WHEN line_exists( lt_conflicts[ risk_level = 'M' is_exempt = abap_false ] ) THEN 1
        ELSE 0 ).
      MODIFY ENTITIES OF zi_iam_lreq_hdr IN LOCAL MODE
        ENTITY Request UPDATE FIELDS ( Status RiskScore )
        WITH VALUE #( ( %tky = ls_request-%tky Status = '02' RiskScore = lv_risk_score ) ).
    ENDLOOP.
    result = VALUE #( FOR req IN lt_requests ( %tky = req-%tky %param = req ) ).
  ENDMETHOD.

  METHOD checkSod.
    READ ENTITIES OF zi_iam_lreq_hdr IN LOCAL MODE
      ENTITY Request ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_requests)
      ENTITY Request BY \_Roles ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_req_roles).
    LOOP AT lt_requests INTO DATA(ls_request).
      DATA(lt_requested_roles) = VALUE zcl_iam_sod_request_checker=>tt_role(
        FOR ls_requested_role IN lt_req_roles WHERE ( ReqUuid = ls_request-ReqUuid )
        ( agr_name = ls_requested_role-RoleName ) ).
      DATA(lt_conflicts) = zcl_iam_sod_request_checker=>check_role_set(
        iv_target_user           = ls_request-TargetUser
        it_requested_roles       = lt_requested_roles
        iv_request_vs_existing   = abap_true ).
      DATA(lv_risk_score) = COND int4(
        WHEN line_exists( lt_conflicts[ risk_level = 'C' is_exempt = abap_false ] ) THEN 3
        WHEN line_exists( lt_conflicts[ risk_level = 'H' is_exempt = abap_false ] ) THEN 2
        WHEN line_exists( lt_conflicts[ risk_level = 'M' is_exempt = abap_false ] ) THEN 1
        ELSE 0 ).
      MODIFY ENTITIES OF zi_iam_lreq_hdr IN LOCAL MODE
        ENTITY Request UPDATE FIELDS ( RiskScore )
        WITH VALUE #( ( %tky = ls_request-%tky RiskScore = lv_risk_score ) ).
      LOOP AT lt_conflicts INTO DATA(ls_conflict).
        APPEND VALUE #(
          %tky = ls_request-%tky
          %param-RuleId = ls_conflict-rule_id
          %param-RuleName = ls_conflict-rule_name
          %param-Role1 = ls_conflict-role_1
          %param-Role2 = ls_conflict-role_2
          %param-RiskLevel = ls_conflict-risk_level
          %param-IsExempt = ls_conflict-is_exempt
          %param-ExemptReason = ls_conflict-exempt_reason
          %param-SuggestedAction = ls_conflict-suggested_action
          %param-IsLocked = ls_conflict-is_locked
          %param-LastLogin = ls_conflict-last_login ) TO result.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.

  METHOD getApprovalRationale.
    READ ENTITIES OF zi_iam_lreq_hdr IN LOCAL MODE
      ENTITY Request ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_requests).
    LOOP AT lt_requests INTO DATA(ls_request).
      IF sy-uname <> ls_request-ApprovedBy.
        AUTHORITY-CHECK OBJECT 'ZIAM_REQ' ID 'ACTVT' FIELD '16'.
        IF sy-subrc <> 0.
          APPEND VALUE #( %tky = ls_request-%tky ) TO failed-request.
          CONTINUE.
        ENDIF.
      ENDIF.
      APPEND VALUE #( %tky = ls_request-%tky %param-ApprovalReason = ls_request-ApprovalReason ) TO result.
    ENDLOOP.
  ENDMETHOD.

  METHOD setDefaultValues.
    READ ENTITIES OF zi_iam_lreq_hdr IN LOCAL MODE
      ENTITY Request
        FIELDS ( ReqId Status ReqType TicketId Reason DurationHours ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_requests).

    LOOP AT lt_requests INTO DATA(ls_request).
      IF ls_request-Status IS INITIAL.
        DATA(lv_req_type) = ls_request-ReqType.
        IF lv_req_type IS INITIAL.
          IF ls_request-TicketId IS NOT INITIAL
             OR ls_request-Reason IS NOT INITIAL
             OR ls_request-DurationHours IS NOT INITIAL.
            lv_req_type = 'F'.
          ELSE.
            lv_req_type = 'J'.
          ENDIF.
        ENDIF.
        MODIFY ENTITIES OF zi_iam_lreq_hdr IN LOCAL MODE
          ENTITY Request
            UPDATE
            FIELDS ( Status ReqId ReqType )
            WITH VALUE #( ( %tky = ls_request-%tky
                            Status  = '01'
                            ReqId   = 'REQ' && sy-uzeit
                            ReqType = lv_req_type ) ).
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

METHOD validateEmail.
  READ ENTITIES OF zi_iam_lreq_hdr IN LOCAL MODE
    ENTITY Request FIELDS ( ReqType Email )
    WITH CORRESPONDING #( keys )
    RESULT DATA(lt_requests).

  LOOP AT lt_requests INTO DATA(ls_request).
    IF ls_request-ReqType <> 'J'.
      CONTINUE.
    ENDIF.

    DATA(lv_email) = CONV string( ls_request-Email ).
    FIND PCRE '^[^\s@]+@[^\s@]+\.[^\s@]+$'
      IN lv_email MATCH COUNT DATA(lv_email_match_count).

    IF lv_email_match_count = 0.
      APPEND VALUE #( %tky = ls_request-%tky ) TO failed-request.
      APPEND VALUE #(
        %tky = ls_request-%tky
        %msg = new_message(
          id       = 'ZMSG_IAM07'
          number   = '101'
          severity = if_abap_behv_message=>severity-error
        ) )
        TO reported-request.
    ENDIF.
  ENDLOOP.
ENDMETHOD.

ENDCLASS.
