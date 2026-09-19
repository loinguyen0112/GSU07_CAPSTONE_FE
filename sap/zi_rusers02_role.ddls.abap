@EndUserText.label: 'IAM User Role Assignment'
@AccessControl.authorizationCheck: #NOT_REQUIRED
define root view entity ZI_RUSERS02_ROLE
  as select from agr_users as a
{
  key a.uname    as UserName,
  key a.agr_name as RoleName,
  key a.from_dat as ValidFrom,
  key a.to_dat   as ValidTo,
      a.exclude  as IsExcluded
}
