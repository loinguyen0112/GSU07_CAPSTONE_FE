@EndUserText.label : 'IAM Firefighter Grant'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #ALLOWED
define table ziam_ff_grant {
  key client     : abap.clnt not null;
  key grant_id   : abap.char(32) not null;
  request_uuid   : sysuuid_x16;
  target_user    : xubname;
  agr_name       : agr_name;
  requester      : xubname;
  approver       : xubname;
  revoked_by     : xubname;
  ticket_id      : abap.char(40);
  reason         : abap.char(255);
  duration_hours : abap.int1;
  status         : abap.char(16);
  start_at       : timestampl;
  end_at         : timestampl;
  requested_at   : timestampl;
  approved_at    : timestampl;
  granted_at     : timestampl;
  revoked_at     : timestampl;
  role_added     : abap.char(1);
  role_from      : abap.dats;
  role_to        : abap.dats;
  retry_count    : abap.int2;
  process_token  : abap.char(32);
  process_until  : timestampl;
  row_version    : abap.int4;
  last_message   : abap.char(255);
  changed_by     : xubname;
  changed_at     : timestampl;
}
