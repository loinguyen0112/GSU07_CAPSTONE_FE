@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Active Firefighter role value help'
@ObjectModel.resultSet.sizeCategory: #XS
define view entity ZI_IAM_FF_ROLE_VH
  as select from ziam_ff_role
{
  key agr_name as RoleName,
      cast( owner as abap.char(40) ) as Description,
      max_hours as MaxHours
}
where is_active = 'X'
