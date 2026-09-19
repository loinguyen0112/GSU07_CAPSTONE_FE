REPORT zpg_iam_access_control.

TABLES usr02.

PARAMETERS p_mode TYPE c LENGTH 1 DEFAULT 'I' OBLIGATORY.
SELECT-OPTIONS s_user FOR usr02-bname.

PARAMETERS:
  p_warn   TYPE i DEFAULT 0,
  p_lock   TYPE i DEFAULT 0,
  p_keydt  TYPE sy-datum DEFAULT sy-datum,
  p_test   AS CHECKBOX DEFAULT 'X'.

AT SELECTION-SCREEN.
  TRANSLATE p_mode TO UPPER CASE.
  IF p_mode <> 'I'
     AND p_mode <> 'E'
     AND p_mode <> 'B'.
    MESSAGE 'Invalid mode. Use I, E, or B only.' TYPE 'E'.
  ENDIF.

START-OF-SELECTION.
  DATA(lo_control) = NEW zcl_iam_access_ctrl(
    iv_simulation = p_test ).

  CASE p_mode.
    WHEN 'I'.
      lo_control->run_inactivity(
        it_bname     = s_user[]
        iv_keydate   = p_keydt
        iv_warn_from = p_warn
        iv_lock_at   = p_lock ).

    WHEN 'E'.
      lo_control->run_firefighter_expiry( ).

    WHEN 'B'.
      lo_control->run_inactivity(
        it_bname     = s_user[]
        iv_keydate   = p_keydt
        iv_warn_from = p_warn
        iv_lock_at   = p_lock ).
      lo_control->run_firefighter_expiry( ).

    WHEN OTHERS.
      WRITE: / 'Invalid mode. Use I/E/B only.'.
  ENDCASE.

  LOOP AT lo_control->get_log( ) INTO DATA(lv_log).
    WRITE: / lv_log.
  ENDLOOP.
