@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'IAM User Administration - Fiori'
@Search.searchable: true
@UI: { headerInfo: { typeName: 'User', typeNamePlural: 'Users', title: { type: #STANDARD, value: 'UserName' } } }
define root view entity ZC_RUSERS02
  provider contract transactional_query
  as projection on ZI_RUSERS02
{
  @Search.defaultSearchElement: true
  @EndUserText.label: 'User Name'
  @UI: { lineItem: [{ position: 10 }], identification: [{ position: 10 }], selectionField: [{ position: 10 }] }
  key UserName,

  @Search.defaultSearchElement: true
  @EndUserText.label: 'Full Name'
  @UI: { lineItem: [{ position: 20 }], identification: [{ position: 20 }] }
  FullName,

  @UI.lineItem: [{ position: 30 }]
  @UI.selectionField: [{ position: 20 }]
  CreatedDate,

  @UI.lineItem: [{ position: 40 }]
  @UI.selectionField: [{ position: 30 }]
  LastLogonDate,

  @UI.lineItem: [{ position: 50 }]
  LastLogonTime,

  @UI.lineItem: [{ position: 60 }]
  @UI.selectionField: [{ position: 40 }]
  UserStatus,

  @UI.lineItem: [{ position: 70 }]
  @UI.selectionField: [{ position: 50 }]
  Department,

  @UI.lineItem: [{ position: 80 }]
  Email,

  @UI.identification: [{ position: 30 }]
  UserGroup,
  @UI.identification: [{ position: 40 }]
  UserFlag,
  @UI.identification: [{ position: 50 }]
  ValidFrom,
  @UI.identification: [{ position: 60 }]
  ValidTo,

  @UI.lineItem: [
    { type: #FOR_ACTION, dataAction: 'lockUser', label: 'Lock' },
    { type: #FOR_ACTION, dataAction: 'unlockUser', label: 'Unlock' },
    { type: #FOR_ACTION, dataAction: 'checkRoles', label: 'Check Roles' },
    { type: #FOR_ACTION, dataAction: 'checkSod', label: 'Check SoD' }
  ]
  @UI.identification: [
    { type: #FOR_ACTION, dataAction: 'lockUser', label: 'Lock' },
    { type: #FOR_ACTION, dataAction: 'unlockUser', label: 'Unlock' },
    { type: #FOR_ACTION, dataAction: 'checkRoles', label: 'Check Roles' },
    { type: #FOR_ACTION, dataAction: 'checkSod', label: 'Check SoD' }
  ]
  _Roles : redirected to ZC_RUSERS02_ROLE
}
