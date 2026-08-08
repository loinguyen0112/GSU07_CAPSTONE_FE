CLASS ltc_access_control DEFINITION
  FINAL
  FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.
  PRIVATE SECTION.
    METHODS simulation_is_read_only FOR TESTING.
ENDCLASS.


CLASS ltc_access_control IMPLEMENTATION.
  METHOD simulation_is_read_only.
    SELECT COUNT( * ) FROM ziam_ctrl_case INTO @DATA(lv_cases_before).
    SELECT COUNT( * ) FROM ziam_ff_grant INTO @DATA(lv_grants_before).
    SELECT COUNT( * ) FROM ziam_aud_log2 INTO @DATA(lv_audit_before).

    DATA lv_cutoff TYPE sy-datum.
    lv_cutoff = sy-datum - 83.
    SELECT SINGLE u~bname
      FROM usr02 AS u
      LEFT OUTER JOIN usr21 AS i
        ON i~bname = u~bname
      WHERE u~ustyp = 'A'
        AND u~bname <> @sy-uname
        AND u~uflag = 0
        AND ( i~idadtype IS INITIAL OR i~idadtype <> '01' )
        AND ( ( u~trdat <> '00000000' AND u~trdat <= @lv_cutoff )
           OR ( u~trdat = '00000000' AND u~erdat <= @lv_cutoff ) )
      INTO @DATA(lv_user).

    DATA(lo_control) = NEW zcl_iam_access_ctrl(
      iv_simulation = abap_true ).
    IF lv_user IS NOT INITIAL.
      DATA lt_user TYPE zcl_iam_access_ctrl=>tt_bname_range.
      lt_user = VALUE #( ( sign = 'I' option = 'EQ' low = lv_user ) ).
      lo_control->run_inactivity(
        it_bname     = lt_user
        iv_keydate   = sy-datum
        iv_warn_from = 83
        iv_lock_at   = 90 ).
    ENDIF.
    lo_control->run_firefighter_expiry( ).

    SELECT COUNT( * ) FROM ziam_ctrl_case INTO @DATA(lv_cases_after).
    SELECT COUNT( * ) FROM ziam_ff_grant INTO @DATA(lv_grants_after).
    SELECT COUNT( * ) FROM ziam_aud_log2 INTO @DATA(lv_audit_after).
    cl_abap_unit_assert=>assert_equals( act = lv_cases_after exp = lv_cases_before ).
    cl_abap_unit_assert=>assert_equals( act = lv_grants_after exp = lv_grants_before ).
    cl_abap_unit_assert=>assert_equals( act = lv_audit_after exp = lv_audit_before ).
  ENDMETHOD.

ENDCLASS.
