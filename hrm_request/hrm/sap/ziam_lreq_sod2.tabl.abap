@EndUserText.label: 'Lifecycle request SoD result'
@AbapCatalog.enhancement.category: #NOT_EXTENSIBLE
@AbapCatalog.tableCategory: #TRANSPARENT
@AbapCatalog.deliveryClass: #A
@AbapCatalog.dataMaintenance: #RESTRICTED
define table ziam_lreq_sod2 {
  key client           : abap.clnt not null;
  key request_uuid     : sysuuid_x16 not null;
  key rule_id          : abap.char(20) not null;
  key role_1           : agr_name not null;
  key role_2           : agr_name not null;
  rule_name            : abap.char(100);
  risk_level           : abap.char(1);
  is_exempt            : abap_boolean;
  exempt_reason        : abap.char(255);
  suggested_action     : abap.char(255);
  is_locked            : abap_boolean;
  last_login           : abap.dats;
  created_at           : abap.utclong;
}
