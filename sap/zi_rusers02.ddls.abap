@EndUserText.label: 'IAM User Administration'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true
define root view entity ZI_RUSERS02
  as select distinct from usr02 as u
    left outer join usr21 as ul
      on ul.bname = u.bname
    left outer join adrp as p
      on p.persnumber = ul.persnumber
    left outer join adcp as po
      on po.persnumber = ul.persnumber
     and po.addrnumber  = ul.addrnumber
    left outer join adr6 as em
      on em.persnumber = ul.persnumber
     and em.addrnumber  = ul.addrnumber
     and em.flgdefault  = 'X'
  association [0..*] to ZI_RUSERS02_ROLE as _Roles
    on $projection.UserName = _Roles.UserName
{
  key u.bname as UserName,
      u.class as UserGroup,
      u.uflag as UserFlag,
      u.erdat as CreatedDate,
      u.trdat as LastLogonDate,
      u.ltime as LastLogonTime,
      u.gltgv as ValidFrom,
      u.gltgb as ValidTo,
      case
        when u.uflag = 0 then 'Active'
        else 'Inactive'
      end as UserStatus,
      p.name_text as FullName,
      po.department as Department,
      em.smtp_addr as Email,
      _Roles
}
