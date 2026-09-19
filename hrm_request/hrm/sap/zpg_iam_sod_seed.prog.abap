*&---------------------------------------------------------------------*
*& Report ZPG_IAM_SOD_SEED
*& Purpose: Seed ten DEV-only sample role-pair SoD rules.
*& Default is simulation. Tick P_APPLY to insert missing rules.
*&---------------------------------------------------------------------*
REPORT zpg_iam_sod_seed.

PARAMETERS p_apply TYPE abap_bool AS CHECKBOX DEFAULT abap_false.

TYPES:
  BEGIN OF ty_seed,
    rule_id          TYPE ziam_sod_rule-rule_id,
    rule_name        TYPE ziam_sod_rule-rule_name,
    conflict_role1   TYPE ziam_sod_rule-conflict_role1,
    conflict_role2   TYPE ziam_sod_rule-conflict_role2,
    risk_level       TYPE ziam_sod_rule-risk_level,
    suggested_action TYPE ziam_sod_rule-suggested_action,
  END OF ty_seed.

DATA lt_seed TYPE STANDARD TABLE OF ty_seed WITH EMPTY KEY.

lt_seed = VALUE #(
  ( rule_id = 'TST001' rule_name = '[TEST] FI posting and CO control'
    conflict_role1 = 'Z_S4HANA_FI' conflict_role2 = 'Z_S4HANA_CO'
    risk_level = 'H' suggested_action = 'RV' )
  ( rule_id = 'TST002' rule_name = '[TEST] MM procurement and SD sales'
    conflict_role1 = 'Z_S4HANA_MM' conflict_role2 = 'Z_S4HANA_SD'
    risk_level = 'H' suggested_action = 'RV' )
  ( rule_id = 'TST003' rule_name = '[TEST] Plant maintenance and quality management'
    conflict_role1 = 'Z_S4HANA_EAM' conflict_role2 = 'Z_S4HANA_QM'
    risk_level = 'M' suggested_action = 'RV' )
  ( rule_id = 'TST004' rule_name = '[TEST] Production planning and warehouse management'
    conflict_role1 = 'Z_S4HANA_PP' conflict_role2 = 'Z_S4HANA_WM'
    risk_level = 'H' suggested_action = 'RV' )
  ( rule_id = 'TST005' rule_name = '[TEST] FI posting and MM procurement'
    conflict_role1 = 'Z_S4HANA_FI' conflict_role2 = 'Z_S4HANA_MM'
    risk_level = 'H' suggested_action = 'RV' )
  ( rule_id = 'TST006' rule_name = '[TEST] CO control and SD sales'
    conflict_role1 = 'Z_S4HANA_CO' conflict_role2 = 'Z_S4HANA_SD'
    risk_level = 'M' suggested_action = 'RV' )
  ( rule_id = 'TST007' rule_name = '[TEST] EAM maintenance and MM procurement'
    conflict_role1 = 'Z_S4HANA_EAM' conflict_role2 = 'Z_S4HANA_MM'
    risk_level = 'M' suggested_action = 'RV' )
  ( rule_id = 'TST008' rule_name = '[TEST] PP planning and FI posting'
    conflict_role1 = 'Z_S4HANA_PP' conflict_role2 = 'Z_S4HANA_FI'
    risk_level = 'H' suggested_action = 'RV' )
  ( rule_id = 'TST009' rule_name = '[TEST] QM quality and warehouse management'
    conflict_role1 = 'Z_S4HANA_QM' conflict_role2 = 'Z_S4HANA_WM'
    risk_level = 'M' suggested_action = 'RV' )
  ( rule_id = 'TST010' rule_name = '[TEST] Fiori configuration and IAM HR administration'
    conflict_role1 = 'Z_S4HANA_FIORICONFIG' conflict_role2 = 'ZROLE_IAM_HR'
    risk_level = 'C' suggested_action = 'RM' ) ).

WRITE: / |Mode: { COND string( WHEN p_apply = abap_true THEN 'APPLY' ELSE 'SIMULATION' ) }|.
SKIP.
ULINE.
WRITE: / 'Rule', 12 'Result', 36 'Role 1', 72 'Role 2', 108 'Risk'.
ULINE.

LOOP AT lt_seed INTO DATA(ls_seed).
  SELECT SINGLE agr_name
    FROM agr_define
    WHERE agr_name = @ls_seed-conflict_role1
    INTO @DATA(lv_role_1).
  IF sy-subrc <> 0.
    WRITE: / ls_seed-rule_id, 12 'Skipped - Role 1 does not exist', 36 ls_seed-conflict_role1,
             72 ls_seed-conflict_role2, 108 ls_seed-risk_level.
    CONTINUE.
  ENDIF.
  SELECT SINGLE agr_name
    FROM agr_define
    WHERE agr_name = @ls_seed-conflict_role2
    INTO @DATA(lv_role_2).
  IF sy-subrc <> 0.
    WRITE: / ls_seed-rule_id, 12 'Skipped - Role 2 does not exist', 36 ls_seed-conflict_role1,
             72 ls_seed-conflict_role2, 108 ls_seed-risk_level.
    CONTINUE.
  ENDIF.

  SELECT SINGLE rule_id
    FROM ziam_sod_rule
    WHERE rule_id = @ls_seed-rule_id
    INTO @DATA(lv_rule_id).
  IF sy-subrc = 0.
    WRITE: / ls_seed-rule_id, 12 'Already exists', 36 ls_seed-conflict_role1,
             72 ls_seed-conflict_role2, 108 ls_seed-risk_level.
    CONTINUE.
  ENDIF.

  IF p_apply = abap_false.
    WRITE: / ls_seed-rule_id, 12 'Would insert', 36 ls_seed-conflict_role1,
             72 ls_seed-conflict_role2, 108 ls_seed-risk_level.
    CONTINUE.
  ENDIF.

  DATA(ls_new_rule) = VALUE ziam_sod_rule(
    rule_id          = ls_seed-rule_id
    rule_name        = ls_seed-rule_name
    rule_type        = 'R'
    conflict_role1   = ls_seed-conflict_role1
    conflict_role2   = ls_seed-conflict_role2
    risk_level       = ls_seed-risk_level
    suggested_action = ls_seed-suggested_action ).
  INSERT ziam_sod_rule FROM @ls_new_rule.
  IF sy-subrc = 0.
    WRITE: / ls_seed-rule_id, 12 'Inserted', 36 ls_seed-conflict_role1,
             72 ls_seed-conflict_role2, 108 ls_seed-risk_level.
  ELSE.
    WRITE: / ls_seed-rule_id, 12 'Insert failed', 36 ls_seed-conflict_role1,
             72 ls_seed-conflict_role2, 108 ls_seed-risk_level.
  ENDIF.
ENDLOOP.

IF p_apply = abap_true.
  COMMIT WORK AND WAIT.
  SKIP.
  WRITE: / 'Only rules reported as Inserted are active. Use SM30 / ZIAM_SOD_RULE to remove TST001-TST010 after DEV testing.'.
ENDIF.
