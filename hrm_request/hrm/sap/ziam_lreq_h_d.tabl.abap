@EndUserText.label : 'Draft table for entity ZI_IAM_LREQ_HDR'
@AbapCatalog.enhancement.category : #EXTENSIBLE_ANY
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table ziam_lreq_h_d {
  key mandt          : mandt not null;
  key requuid        : sysuuid_x16 not null;
  reqid              : abap.char(20);
  reqtype            : abap.char(1);
  reqtypetext        : abap.char(20);
  targetuser         : xubname;
  firstname          : abap.char(40);
  lastname           : abap.char(40);
  department         : abap.char(40);
  status             : abap.char(2);
  statustext         : abap.char(20);
  statuscriticality  : abap.int1;
  riskscore          : abap.int4;
  requestedby        : xubname;
  approvedby         : xubname;
  title              : ad_title;
  email              : ad_smtpadr;
  telephone          : ad_tlnmbr;
  mobile             : ad_tlnmbr;
  fax                : ad_fxnmbr;
  ticketid           : abap.char(40);
  reason             : abap.char(255);
  durationhours      : abap.int1;
  approvalreason     : abap.char(255);
  createdby          : abp_creation_user;
  createdat          : abp_creation_tstmpl;
  lastchangedby      : abp_locinst_lastchange_user;
  lastchangedat      : abp_locinst_lastchange_tstmpl;
  locallastchangedat : abp_lastchange_tstmpl;
  "%admin"           : include sych_bdl_draft_admin_inc;
}
