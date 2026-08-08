@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Lifecycle Request Header - Interface'
@Search.searchable: true
define root view entity ZI_IAM_LREQ_HDR
  as select from ziam_lreq_hdr2
  composition [0..*] of ZI_IAM_REQ_ROLE as _Roles
  association [0..1] to ZI_IAM_FF_GRANT_REQ as _FfGrant
    on $projection.ReqUuid = _FfGrant.RequestUuid
{
  key req_uuid as ReqUuid,

  @Search.defaultSearchElement: true
  @Search.fuzzinessThreshold: 0.8
  req_id as ReqId,

  req_type as ReqType,
  cast( case req_type
    when 'J' then 'Joiner'
    when 'M' then 'Mover'
    when 'L' then 'Leaver'
    when 'F' then 'Firefighter Access'
    else 'Unknown'
  end as abap.char(20)) as ReqTypeText,

  @Search.defaultSearchElement: true
  @Search.fuzzinessThreshold: 0.8
  target_user as TargetUser,

  @Search.defaultSearchElement: true
  @Search.fuzzinessThreshold: 0.8
  first_name as FirstName,

  @Search.defaultSearchElement: true
  @Search.fuzzinessThreshold: 0.8
  last_name as LastName,

  department as Department,
  title as Title,
  email as Email,
  telephone as Telephone,
  mobile as Mobile,
  fax as Fax,
  ticket_id as TicketId,
  reason as Reason,
  duration_hours as DurationHours,
  approval_reason as ApprovalReason,
  _FfGrant.GrantStatus as FfGrantStatus,
  _FfGrant.StartAt as FfStartAt,
  _FfGrant.EndAt as FfEndAt,

  status as Status,
  cast( case status
    when '01' then 'Draft'
    when '02' then 'Submitted'
    when '03' then 'Approved'
    when '04' then 'Rejected'
    else 'New'
  end as abap.char(20)) as StatusText,

  cast( case status
    when '01' then 0
    when '02' then 2
    when '03' then 3
    when '04' then 1
    else 0
  end as abap.int1) as StatusCriticality,

  risk_score as RiskScore,
  requested_by as RequestedBy,
  approved_by as ApprovedBy,

  @Semantics.user.createdBy: true
  created_by as CreatedBy,
  @Semantics.systemDateTime.createdAt: true
  created_at as CreatedAt,
  @Semantics.user.lastChangedBy: true
  last_changed_by as LastChangedBy,
  @Semantics.systemDateTime.lastChangedAt: true
  last_changed_at as LastChangedAt,
  @Semantics.systemDateTime.localInstanceLastChangedAt: true
  local_last_changed_at as LocalLastChangedAt,

  _Roles,
  _FfGrant
}
