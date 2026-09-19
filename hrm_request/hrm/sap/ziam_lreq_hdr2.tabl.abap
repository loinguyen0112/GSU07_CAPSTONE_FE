@EndUserText.label : 'Lifecycle Req Header'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #ALLOWED
define table ziam_lreq_hdr2 {
  key client            : abap.clnt not null;
  key req_uuid          : sysuuid_x16 not null;
  req_id                : abap.char(20);
  req_type              : abap.char(1);
  target_user           : xubname;
  first_name            : abap.char(40);
  last_name             : abap.char(40);
  department            : abap.char(40);
  status                : abap.char(2);
  risk_score            : abap.int4;
  requested_by          : xubname;
  approved_by           : xubname;
  title                 : ad_title;
  email                 : ad_smtpadr;
  telephone             : ad_tlnmbr;
  mobile                : ad_tlnmbr;
  fax                   : ad_fxnmbr;
  ticket_id             : abap.char(40);
  reason                : abap.char(255);
  duration_hours        : abap.int1;
  approval_reason       : abap.char(255);
  created_by            : abp_creation_user;
  created_at            : abp_creation_tstmpl;
  last_changed_by       : abp_locinst_lastchange_user;
  last_changed_at       : abp_locinst_lastchange_tstmpl;
  local_last_changed_at : abp_lastchange_tstmpl;
}
