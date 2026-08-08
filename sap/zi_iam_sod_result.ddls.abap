@EndUserText.label: 'Lifecycle request SoD result'
define root view entity ZI_IAM_SOD_RESULT
  as select from ziam_lreq_sod2
{
  key request_uuid          as RequestUuid,
  key rule_id               as RuleId,
  key role_1                as Role1,
  key role_2                as Role2,
      rule_name             as RuleName,
      risk_level            as RiskLevel,
      is_exempt             as IsExempt,
      exempt_reason         as ExemptReason,
      suggested_action      as SuggestedAction,
      is_locked             as IsLocked,
      last_login            as LastLogin,
      created_at            as CreatedAt
}
