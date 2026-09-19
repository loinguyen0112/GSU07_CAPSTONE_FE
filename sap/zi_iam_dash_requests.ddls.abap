@EndUserText.label: 'IAM Dashboard Requests'
@AccessControl.authorizationCheck: #NOT_REQUIRED
define root view entity ZI_IAM_DASH_REQUESTS
  as select from ziam_lreq_hdr2 as r
{
  key r.req_uuid            as RequestUuid,
      r.req_id              as RequestId,
      r.req_type            as RequestType,
      r.target_user         as TargetUser,
      r.first_name          as FirstName,
      r.last_name           as LastName,
      r.department          as Department,
      r.status              as Status,
      r.risk_score          as RiskScore,
      r.requested_by        as RequestedBy,
      r.approved_by         as ApprovedBy,
      r.created_at          as CreatedAt,
      r.last_changed_at     as LastChangedAt
}
