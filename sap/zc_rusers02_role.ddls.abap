@EndUserText.label: 'IAM User Role Assignment - Fiori'
define root view entity ZC_RUSERS02_ROLE
  as projection on ZI_RUSERS02_ROLE
{
  key UserName,
  key RoleName,
  key ValidFrom,
  key ValidTo,
      IsExcluded
}
