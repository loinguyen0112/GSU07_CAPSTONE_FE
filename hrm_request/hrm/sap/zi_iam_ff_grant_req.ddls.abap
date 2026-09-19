@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Firefighter grant by lifecycle request'
define view entity ZI_IAM_FF_GRANT_REQ
  as select from ziam_ff_grant
{
  key request_uuid as RequestUuid,
  key grant_id     as GrantId,
      status       as GrantStatus,
      start_at     as StartAt,
      end_at       as EndAt
}
