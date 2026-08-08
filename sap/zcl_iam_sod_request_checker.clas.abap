CLASS zcl_iam_sod_request_checker DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES:
      BEGIN OF ty_role,
        agr_name TYPE agr_name,
      END OF ty_role,
      tt_role TYPE SORTED TABLE OF ty_role WITH UNIQUE KEY agr_name,
      BEGIN OF ty_conflict,
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
      tt_conflict TYPE STANDARD TABLE OF ty_conflict WITH EMPTY KEY.

    CLASS-METHODS check_role_set
      IMPORTING
        iv_target_user     TYPE xubname
        it_requested_roles TYPE tt_role
        iv_request_vs_existing TYPE abap_bool DEFAULT abap_false
      RETURNING
        VALUE(rt_conflicts) TYPE tt_conflict.
ENDCLASS.


CLASS zcl_iam_sod_request_checker IMPLEMENTATION.
  METHOD check_role_set.
    DATA lt_existing_roles TYPE tt_role.
    DATA lt_roles TYPE tt_role.

    SELECT agr_name
      FROM agr_users
      WHERE uname = @iv_target_user
        AND from_dat <= @sy-datum
        AND to_dat >= @sy-datum
        AND exclude = @space
      INTO TABLE @DATA(lt_assigned_roles).
    LOOP AT lt_assigned_roles INTO DATA(ls_assigned_role).
      IF NOT line_exists( lt_existing_roles[ agr_name = ls_assigned_role-agr_name ] ).
        INSERT VALUE #( agr_name = ls_assigned_role-agr_name ) INTO TABLE lt_existing_roles.
      ENDIF.
    ENDLOOP.

    "The administrator scan evaluates every existing role pair.
    "The request flow evaluates only a newly requested role against an existing role.
    IF iv_request_vs_existing = abap_false.
      lt_roles = lt_existing_roles.
      LOOP AT it_requested_roles INTO DATA(ls_requested_role).
        IF NOT line_exists( lt_roles[ agr_name = ls_requested_role-agr_name ] ).
          INSERT ls_requested_role INTO TABLE lt_roles.
        ENDIF.
      ENDLOOP.
    ENDIF.

    SELECT rule_id, rule_name, conflict_role1, conflict_role2, risk_level, suggested_action
      FROM ziam_sod_rule
      WHERE rule_type = 'R'
      INTO TABLE @DATA(lt_rules).
    SELECT SINGLE uflag, trdat
      FROM usr02
      WHERE bname = @iv_target_user
      INTO @DATA(ls_user_status).

    LOOP AT lt_rules INTO DATA(ls_rule).
      IF iv_request_vs_existing = abap_true.
        DATA(lv_role1_requested) = xsdbool( line_exists( it_requested_roles[ agr_name = ls_rule-conflict_role1 ] ) ).
        DATA(lv_role2_requested) = xsdbool( line_exists( it_requested_roles[ agr_name = ls_rule-conflict_role2 ] ) ).
        DATA(lv_role1_existing) = xsdbool( line_exists( lt_existing_roles[ agr_name = ls_rule-conflict_role1 ] ) ).
        DATA(lv_role2_existing) = xsdbool( line_exists( lt_existing_roles[ agr_name = ls_rule-conflict_role2 ] ) ).
        IF ( lv_role1_requested = abap_false OR lv_role2_existing = abap_false )
           AND ( lv_role2_requested = abap_false OR lv_role1_existing = abap_false ).
          CONTINUE.
        ENDIF.
      ELSE.
        READ TABLE lt_roles TRANSPORTING NO FIELDS WITH KEY agr_name = ls_rule-conflict_role1.
        IF sy-subrc <> 0.
          CONTINUE.
        ENDIF.
        READ TABLE lt_roles TRANSPORTING NO FIELDS WITH KEY agr_name = ls_rule-conflict_role2.
        IF sy-subrc <> 0.
          CONTINUE.
        ENDIF.
      ENDIF.

      DATA(ls_conflict) = VALUE ty_conflict(
        rule_id          = ls_rule-rule_id
        rule_name        = ls_rule-rule_name
        role_1           = ls_rule-conflict_role1
        role_2           = ls_rule-conflict_role2
        risk_level       = ls_rule-risk_level
        suggested_action = ls_rule-suggested_action
        is_locked        = xsdbool( ls_user_status-uflag <> 0 )
        last_login       = ls_user_status-trdat ).
      SELECT SINGLE reason
        FROM ziam_sod_exempt
        WHERE rule_id = @ls_rule-rule_id
          AND uname = @iv_target_user
          AND is_active = 'X'
          AND valid_from <= @sy-datum
          AND valid_to >= @sy-datum
        INTO @ls_conflict-exempt_reason.
      ls_conflict-is_exempt = xsdbool( sy-subrc = 0 ).
      APPEND ls_conflict TO rt_conflicts.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.
