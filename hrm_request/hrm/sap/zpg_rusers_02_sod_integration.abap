*& ZPG_RUSERS_02 integration when using one combined SoD include.
*&
*& 1. After DATA gv_ok_code TYPE sy-ucomm. (before CLASS lcl_alv_events):
INCLUDE zpg_iam_rusers_sod_i01.

*& 2. In lcl_alv_events->on_toolbar, after the REMOVE_AUTH button:
    CLEAR ls_button. ls_button-function = 'CHECK_SOD'. ls_button-icon = icon_check.
    ls_button-quickinfo = 'Check segregation-of-duties conflicts'. ls_button-text = 'Check SoD'.
    APPEND ls_button TO e_object->mt_toolbar.

*& 3. In FORM handle_alv_ucomm CASE:
    WHEN 'CHECK_SOD'.    PERFORM check_sod.
