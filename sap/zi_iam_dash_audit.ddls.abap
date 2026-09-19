@EndUserText.label: 'IAM Dashboard Audit Events'
@AccessControl.authorizationCheck: #NOT_REQUIRED
define root view entity ZI_IAM_DASH_AUDIT
  as select from ziam_aud_log2 as a
{
  key a.log_id          as AuditId,
      a.target_user     as TargetUser,
      a.action_type     as ActionType,
      a.performed_by    as PerformedBy,
      a.timestamp       as ChangedAt,
      a.source_module   as SourceModule
}
