*&---------------------------------------------------------------------*
*& Report ZPG_IAM_FF_SEED
*& Purpose: Seed DEV Firefighter allowlist records for UI/integration test.
*& Default is simulation. Tick P_APPLY to insert missing allowlist rows.
*&---------------------------------------------------------------------*
REPORT zpg_iam_ff_seed.

PARAMETERS p_apply TYPE abap_bool AS CHECKBOX DEFAULT abap_false.
PARAMETERS p_owner TYPE xubname DEFAULT sy-uname OBLIGATORY.

TYPES:
  BEGIN OF ty_seed,
    agr_name  TYPE agr_name,
    max_hours TYPE ziam_ff_role-max_hours,
  END OF ty_seed.

DATA lt_seed TYPE STANDARD TABLE OF ty_seed WITH EMPTY KEY.
lt_seed = VALUE #(
  ( agr_name = 'ZROLE_IAM_HR' max_hours = 2 )
  ( agr_name = 'Z_S4HANA_FI' max_hours = 4 ) ).

WRITE: / |Mode: { COND string( WHEN p_apply = abap_true THEN 'APPLY' ELSE 'SIMULATION' ) }; owner: { p_owner }|.
SKIP.
ULINE.
WRITE: / 'Role', 35 'Maximum hours', 55 'Result'.
ULINE.

LOOP AT lt_seed INTO DATA(ls_seed).
  SELECT SINGLE agr_name
    FROM agr_define
    WHERE agr_name = @ls_seed-agr_name
    INTO @DATA(lv_existing_role).
  IF sy-subrc <> 0.
    WRITE: / ls_seed-agr_name, 35 ls_seed-max_hours, 55 'Skipped - PFCG role does not exist'.
    CONTINUE.
  ENDIF.

  SELECT SINGLE agr_name
    FROM ziam_ff_role
    WHERE agr_name = @ls_seed-agr_name
    INTO @DATA(lv_existing_allowlist).
  IF sy-subrc = 0.
    WRITE: / ls_seed-agr_name, 35 ls_seed-max_hours, 55 'Already in Firefighter allowlist'.
    CONTINUE.
  ENDIF.

  IF p_apply = abap_false.
    WRITE: / ls_seed-agr_name, 35 ls_seed-max_hours, 55 'Would insert active DEV test allowlist row'.
    CONTINUE.
  ENDIF.

  GET TIME STAMP FIELD DATA(lv_now).
  DATA(ls_new_allowlist) = VALUE ziam_ff_role(
    agr_name     = ls_seed-agr_name
    owner        = p_owner
    max_hours    = ls_seed-max_hours
    sod_check    = 'X'
    exclusive_ff = 'X'
    is_active    = 'X'
    changed_by   = sy-uname
    changed_at   = lv_now ).
  INSERT ziam_ff_role FROM @ls_new_allowlist.
  IF sy-subrc = 0.
    WRITE: / ls_seed-agr_name, 35 ls_seed-max_hours, 55 'Inserted and active'.
  ELSE.
    WRITE: / ls_seed-agr_name, 35 ls_seed-max_hours, 55 'Insert failed'.
  ENDIF.
ENDLOOP.

IF p_apply = abap_true.
  COMMIT WORK AND WAIT.
  SKIP.
  WRITE: / 'DEV test roles are active immediately. Remove them from ZIAM_FF_ROLE after testing if they are not approved configuration.'.
ENDIF.
