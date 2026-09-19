CLASS zcl_iam_sod_checker DEFINITION
  PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES:
      BEGIN OF ty_conflict,
        uname            TYPE xubname,
        agr_name_1       TYPE agr_name,
        agr_name_2       TYPE agr_name,
        rule_id          TYPE char10,
        rule_name        TYPE char100,
        risk_level       TYPE char1,
        risk_text        TYPE char20,
        last_login       TYPE xuldate,
        last_login_time  TYPE xultime,
        days_inactive    TYPE i,
        is_locked        TYPE char1,
        is_exempt        TYPE char1,
        exempt_reason    TYPE char255,
        suggested_action TYPE char2,
        action_text      TYPE char30,
        row_color        TYPE char4,
      END OF ty_conflict,
      tt_conflicts TYPE STANDARD TABLE OF ty_conflict WITH DEFAULT KEY.

    CLASS-METHODS run
      IMPORTING
        iv_uname      TYPE xubname  OPTIONAL
        iv_agr_name   TYPE agr_name OPTIONAL
        iv_risk_level TYPE char1    OPTIONAL
      RETURNING
        VALUE(rt_result) TYPE tt_conflicts.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_rule,
        rule_id          TYPE char10,
        rule_name        TYPE char100,
        rule_type        TYPE char1,
        conflict_role1   TYPE agr_name,
        conflict_role2   TYPE agr_name,
        risk_level       TYPE char1,
        suggested_action TYPE char2,
      END OF ty_rule,
      tt_rules TYPE STANDARD TABLE OF ty_rule WITH DEFAULT KEY,
      BEGIN OF ty_user_role,
        uname    TYPE xubname,
        agr_name TYPE agr_name,
      END OF ty_user_role,
      tt_user_roles TYPE STANDARD TABLE OF ty_user_role WITH DEFAULT KEY,
      BEGIN OF ty_login,
        bname TYPE xubname,
        trdat TYPE xuldate,
        ltime TYPE xultime,
        uflag TYPE xuuflag,
      END OF ty_login,
      tt_logins TYPE STANDARD TABLE OF ty_login WITH DEFAULT KEY,
      BEGIN OF ty_exempt,
        rule_id    TYPE char10,
        uname      TYPE xubname,
        agr_name   TYPE agr_name,
        reason     TYPE char255,
        valid_from TYPE dats,
        valid_to   TYPE dats,
      END OF ty_exempt,
      tt_exempts TYPE STANDARD TABLE OF ty_exempt WITH DEFAULT KEY.

    CLASS-METHODS get_active_rules
      RETURNING VALUE(rt_rules) TYPE tt_rules.
    CLASS-METHODS get_user_roles
      IMPORTING iv_uname TYPE xubname OPTIONAL iv_agr_name TYPE agr_name OPTIONAL
      RETURNING VALUE(rt_user_roles) TYPE tt_user_roles.
    CLASS-METHODS get_logins
      IMPORTING it_user_roles TYPE tt_user_roles
      RETURNING VALUE(rt_logins) TYPE tt_logins.
    CLASS-METHODS check_role_conflicts
      IMPORTING it_rules TYPE tt_rules it_user_roles TYPE tt_user_roles
      CHANGING ct_result TYPE tt_conflicts.
    CLASS-METHODS get_exemptions
      RETURNING VALUE(rt_exempts) TYPE tt_exempts.
    CLASS-METHODS apply_exemptions
      IMPORTING it_exempts TYPE tt_exempts
      CHANGING ct_result TYPE tt_conflicts.
    CLASS-METHODS enrich_data
      IMPORTING it_logins TYPE tt_logins
      CHANGING ct_result TYPE tt_conflicts.
    CLASS-METHODS get_risk_text
      IMPORTING iv_risk TYPE char1 RETURNING VALUE(rv_text) TYPE char20.
    CLASS-METHODS get_risk_color
      IMPORTING iv_risk TYPE char1 RETURNING VALUE(rv_color) TYPE char4.
    CLASS-METHODS get_action_text
      IMPORTING iv_action TYPE char2 RETURNING VALUE(rv_text) TYPE char30.
ENDCLASS.

CLASS zcl_iam_sod_checker IMPLEMENTATION.

  METHOD run.
    DATA(lt_rules) = get_active_rules( ).
    IF lt_rules IS INITIAL. RETURN. ENDIF.
    DATA(lt_user_roles) = get_user_roles( iv_uname = iv_uname iv_agr_name = iv_agr_name ).
    IF lt_user_roles IS INITIAL. RETURN. ENDIF.
    check_role_conflicts( EXPORTING it_rules = lt_rules it_user_roles = lt_user_roles
                          CHANGING  ct_result = rt_result ).
    IF rt_result IS INITIAL. RETURN. ENDIF.
    IF iv_risk_level IS NOT INITIAL.
      DELETE rt_result WHERE risk_level <> iv_risk_level.
    ENDIF.
    DATA(lt_logins) = get_logins( lt_user_roles ).
    enrich_data( EXPORTING it_logins = lt_logins CHANGING ct_result = rt_result ).
    DATA(lt_exempts) = get_exemptions( ).
    apply_exemptions( EXPORTING it_exempts = lt_exempts CHANGING ct_result = rt_result ).
    SORT rt_result BY risk_level uname.
  ENDMETHOD.

  METHOD get_active_rules.
    SELECT rule_id, rule_name, rule_type, conflict_role1, conflict_role2,
           risk_level, suggested_action
      FROM ziam_sod_rule
      WHERE rule_type IS NOT INITIAL
      INTO TABLE @rt_rules.
  ENDMETHOD.

  METHOD get_user_roles.
    DATA lv_today TYPE dats.
    lv_today = sy-datum.
    "Valid-date scans cannot use AGR_USERS generic buffering; issue one set-based DB read.
    IF iv_uname IS NOT INITIAL AND iv_agr_name IS NOT INITIAL.
      SELECT agr_name, uname FROM agr_users BYPASSING BUFFER
        WHERE uname = @iv_uname AND agr_name = @iv_agr_name
          AND from_dat <= @lv_today AND to_dat >= @lv_today AND exclude = ' '
        INTO TABLE @rt_user_roles.
    ELSEIF iv_uname IS NOT INITIAL.
      SELECT agr_name, uname FROM agr_users BYPASSING BUFFER
        WHERE uname = @iv_uname
          AND from_dat <= @lv_today AND to_dat >= @lv_today AND exclude = ' '
        INTO TABLE @rt_user_roles.
    ELSEIF iv_agr_name IS NOT INITIAL.
      SELECT agr_name, uname FROM agr_users BYPASSING BUFFER
        WHERE agr_name = @iv_agr_name
          AND from_dat <= @lv_today AND to_dat >= @lv_today AND exclude = ' '
        INTO TABLE @rt_user_roles.
    ELSE.
      SELECT agr_name, uname FROM agr_users BYPASSING BUFFER
        WHERE from_dat <= @lv_today AND to_dat >= @lv_today AND exclude = ' '
        INTO TABLE @rt_user_roles.
    ENDIF.
    SORT rt_user_roles BY uname agr_name.
    DELETE ADJACENT DUPLICATES FROM rt_user_roles COMPARING uname agr_name.
  ENDMETHOD.

  METHOD get_logins.
    DATA lt_unames TYPE RANGE OF xubname.
    LOOP AT it_user_roles INTO DATA(ls_ur).
      APPEND VALUE #( sign = 'I' option = 'EQ' low = ls_ur-uname ) TO lt_unames.
    ENDLOOP.
    DELETE ADJACENT DUPLICATES FROM lt_unames COMPARING low.
    CHECK lt_unames IS NOT INITIAL.
    "A multi-user lookup must not attempt the single-record USR02 buffer.
    SELECT bname, trdat, ltime, uflag
      FROM usr02 BYPASSING BUFFER
      WHERE bname IN @lt_unames
      INTO TABLE @rt_logins.
  ENDMETHOD.

  METHOD check_role_conflicts.
    DATA lt_map TYPE HASHED TABLE OF ty_user_role WITH UNIQUE KEY uname agr_name.
    lt_map = it_user_roles.
    LOOP AT it_rules INTO DATA(ls_rule) WHERE rule_type = 'R'.
      LOOP AT it_user_roles INTO DATA(ls_ur) WHERE agr_name = ls_rule-conflict_role1.
        READ TABLE lt_map WITH KEY uname = ls_ur-uname agr_name = ls_rule-conflict_role2
          TRANSPORTING NO FIELDS.
        IF sy-subrc = 0.
          APPEND VALUE #(
            uname            = ls_ur-uname
            agr_name_1       = ls_rule-conflict_role1
            agr_name_2       = ls_rule-conflict_role2
            rule_id          = ls_rule-rule_id
            rule_name        = ls_rule-rule_name
            risk_level       = ls_rule-risk_level
            risk_text        = get_risk_text( ls_rule-risk_level )
            suggested_action = ls_rule-suggested_action
            action_text      = get_action_text( ls_rule-suggested_action )
            row_color        = get_risk_color( ls_rule-risk_level )
          ) TO ct_result.
        ENDIF.
      ENDLOOP.
    ENDLOOP.
    SORT ct_result BY uname agr_name_1 rule_id.
    DELETE ADJACENT DUPLICATES FROM ct_result COMPARING uname agr_name_1 rule_id.
  ENDMETHOD.

  METHOD get_exemptions.
    SELECT rule_id, uname, agr_name, reason, valid_from, valid_to
      FROM ziam_sod_exempt
      WHERE is_active = 'X' AND valid_from <= @sy-datum AND valid_to >= @sy-datum
      INTO CORRESPONDING FIELDS OF TABLE @rt_exempts.
  ENDMETHOD.

  METHOD apply_exemptions.
    LOOP AT ct_result ASSIGNING FIELD-SYMBOL(<ls_c>).
      READ TABLE it_exempts INTO DATA(ls_ex)
        WITH KEY rule_id = <ls_c>-rule_id uname = <ls_c>-uname.
      IF sy-subrc = 0.
        <ls_c>-is_exempt     = 'X'.
        <ls_c>-exempt_reason = ls_ex-reason.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD enrich_data.
    LOOP AT ct_result ASSIGNING FIELD-SYMBOL(<ls_c>).
      READ TABLE it_logins INTO DATA(ls_l) WITH KEY bname = <ls_c>-uname.
      IF sy-subrc = 0.
        <ls_c>-last_login      = ls_l-trdat.
        <ls_c>-last_login_time = ls_l-ltime.
        <ls_c>-days_inactive   = sy-datum - ls_l-trdat.
        <ls_c>-is_locked       = COND #( WHEN ls_l-uflag <> 0 THEN 'X' ELSE ' ' ).
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD get_risk_text.
    rv_text = SWITCH #( iv_risk WHEN 'C' THEN 'Critical'
      WHEN 'H' THEN 'High' WHEN 'M' THEN 'Medium' ELSE 'Unknown' ).
  ENDMETHOD.

  METHOD get_risk_color.
    rv_color = SWITCH #( iv_risk WHEN 'C' THEN 'C610'
      WHEN 'H' THEN 'C710' WHEN 'M' THEN 'C310' ELSE '    ' ).
  ENDMETHOD.

  METHOD get_action_text.
    rv_text = SWITCH #( iv_action WHEN 'RM' THEN 'Remove Conflicting Role'
      WHEN 'EX' THEN 'Add Exemption' WHEN 'RV' THEN 'Review with Manager'
      ELSE 'Investigate' ).
  ENDMETHOD.

ENDCLASS.
