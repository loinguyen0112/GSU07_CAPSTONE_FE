@EndUserText.label: 'SoD conflict action result'
define abstract entity ZI_IAM_SOD_ACTION_RESULT {
  RuleId          : abap.char(20);
  RuleName        : abap.char(100);
  Role1           : agr_name;
  Role2           : agr_name;
  RiskLevel       : abap.char(1);
  IsExempt        : abap_boolean;
  ExemptReason    : abap.char(255);
  SuggestedAction : abap.char(255);
  IsLocked        : abap_boolean;
  LastLogin       : abap.dats;
}
