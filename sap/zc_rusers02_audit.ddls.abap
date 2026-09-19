@EndUserText.label: 'IAM User Administration Audit - Fiori'
define view entity ZC_RUSERS02_AUDIT
  as select from ZI_RUSERS02_AUDIT
{
  key AuditId,
      TargetUser,
      ActionType,
      PerformedBy,
      OldValue,
      NewValue,
      CreatedAt,
      SourceModule
}
