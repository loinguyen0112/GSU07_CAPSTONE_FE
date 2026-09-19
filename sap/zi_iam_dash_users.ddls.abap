@EndUserText.label: 'IAM Dashboard Users'
@AccessControl.authorizationCheck: #NOT_REQUIRED
define root view entity ZI_IAM_DASH_USERS
  as select distinct from usr02 as u
    left outer join usr21 as ul
      on ul.bname = u.bname
    left outer join adrp as p
      on p.persnumber = ul.persnumber
{
  key u.bname      as UserName,
      p.name_text   as FullName,
      u.uflag       as UserFlag,
      u.erdat       as CreatedDate,
      u.trdat       as LastLogonDate,
      u.ltime       as LastLogonTime,
      case
        when u.uflag = 0 then 'Active'
        else 'Inactive'
      end           as UserStatus
}
