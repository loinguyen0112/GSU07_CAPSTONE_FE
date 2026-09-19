@EndUserText.label: 'ZPG_RUSERS_02 User Administration'
define service ZSD_RUSERS02 {
  expose ZC_RUSERS02       as Users;
  expose ZC_RUSERS02_ROLE  as Roles;
  expose ZC_RUSERS02_AUDIT as Audit;
}
