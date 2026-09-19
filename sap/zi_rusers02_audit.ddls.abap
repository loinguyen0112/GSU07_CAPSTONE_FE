@EndUserText.label: 'IAM User Administration Audit'
@AccessControl.authorizationCheck: #NOT_REQUIRED
define view entity ZI_RUSERS02_AUDIT
  as select from ziam_aud_log2 as a
{
  key a.log_id       as AuditId,
      a.target_user  as TargetUser,
      a.action_type  as ActionType,
      a.performed_by as PerformedBy,
      a.old_value    as OldValue,
      a.new_value    as NewValue,
      a.timestamp    as CreatedAt,
      a.source_module as SourceModule
}
