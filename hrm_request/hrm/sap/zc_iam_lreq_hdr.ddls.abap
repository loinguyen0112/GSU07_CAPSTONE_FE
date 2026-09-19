@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Lifecycle Request - Projection'
@Search.searchable: true
@UI: {
  headerInfo: { typeName: 'Request', typeNamePlural: 'Requests', title: { type: #STANDARD, value: 'ReqId' } }
}
define root view entity ZC_IAM_LREQ_HDR
  provider contract transactional_query
  as projection on ZI_IAM_LREQ_HDR
{
  @UI.hidden: true
  key ReqUuid,

  @UI.facet: [
    { id: 'GeneralInfo', purpose: #STANDARD, type: #IDENTIFICATION_REFERENCE, label: 'Person', position: 10 },
    { id: 'WorkCenter', purpose: #STANDARD, type: #FIELDGROUP_REFERENCE, label: 'Work Center', targetQualifier: 'WorkCenter', position: 15 },
    { id: 'Communication', purpose: #STANDARD, type: #FIELDGROUP_REFERENCE, label: 'Communication', targetQualifier: 'Communication', position: 18 },
    { id: 'Firefighter', purpose: #STANDARD, type: #FIELDGROUP_REFERENCE, label: 'Firefighter Access', targetQualifier: 'Firefighter', position: 19 },
    { id: 'Roles', purpose: #STANDARD, type: #LINEITEM_REFERENCE, label: 'Requested Roles', position: 20, targetElement: '_Roles' }
  ]

  @Search.defaultSearchElement: true
  @EndUserText.label: 'Request ID'
  @UI: { lineItem: [{ position: 10 }], identification: [{ position: 10 }], selectionField: [{ position: 10 }] }
  ReqId,

  @EndUserText.label: 'Request Type'
  @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_IAM_REQTYPE_VH', element: 'ReqType' } }]
  @ObjectModel.text.element: ['ReqTypeText']
  @UI.textArrangement: #TEXT_ONLY
  @UI: { lineItem: [{ position: 20 }], identification: [{ position: 20 }], selectionField: [{ position: 20 }] }
  ReqType,

  @UI.hidden: true
  ReqTypeText,

  @Search.defaultSearchElement: true
  @EndUserText.label: 'User'
  @UI: { lineItem: [{ position: 30 }], identification: [{ position: 30 }] }
  TargetUser,

  @EndUserText.label: 'Title'
  @UI: { identification: [{ position: 35 }] }
  Title,

  @Search.defaultSearchElement: true
  @EndUserText.label: 'First Name'
  @UI: { identification: [{ position: 40 }] }
  FirstName,

  @Search.defaultSearchElement: true
  @EndUserText.label: 'Last Name'
  @UI: { identification: [{ position: 50 }] }
  LastName,

  @EndUserText.label: 'Department'
  @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_IAM_DEPT_VH', element: 'DepartmentID' } }]
  @UI: { lineItem: [{ position: 40 }], fieldGroup: [{ qualifier: 'WorkCenter', position: 10 }], selectionField: [{ position: 30 }] }
  Department,

  @EndUserText.label: 'Telephone'
  @UI: { fieldGroup: [{ qualifier: 'Communication', position: 10 }] }
  Telephone,

  @EndUserText.label: 'Mobile Phone'
  @UI: { fieldGroup: [{ qualifier: 'Communication', position: 20 }] }
  Mobile,

  @EndUserText.label: 'Fax'
  @UI: { fieldGroup: [{ qualifier: 'Communication', position: 30 }] }
  Fax,

  @EndUserText.label: 'E-Mail Address'
  @UI: { fieldGroup: [{ qualifier: 'Communication', position: 40 }] }
  Email,

  @EndUserText.label: 'Ticket ID'
  @UI: { fieldGroup: [{ qualifier: 'Firefighter', position: 10 }] }
  TicketId,

  @EndUserText.label: 'Emergency Reason'
  @UI: { fieldGroup: [{ qualifier: 'Firefighter', position: 20 }] }
  Reason,

  @EndUserText.label: 'Duration Hours'
  @UI: { fieldGroup: [{ qualifier: 'Firefighter', position: 30 }] }
  DurationHours,

  @EndUserText.label: 'Grant Status'
  @UI: { fieldGroup: [{ qualifier: 'Firefighter', position: 40 }] }
  FfGrantStatus,

  @EndUserText.label: 'Grant Start'
  @UI: { fieldGroup: [{ qualifier: 'Firefighter', position: 50 }] }
  FfStartAt,

  @EndUserText.label: 'Grant End'
  @UI: { fieldGroup: [{ qualifier: 'Firefighter', position: 60 }] }
  FfEndAt,

  @EndUserText.label: 'Status'
  @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_IAM_STATUS_VH', element: 'Status' } }]
  @ObjectModel.text.element: ['StatusText']
  @UI.textArrangement: #TEXT_ONLY
  @UI: { lineItem: [
           { position: 50, criticality: 'StatusCriticality', criticalityRepresentation: #WITHOUT_ICON },
           { type: #FOR_ACTION, dataAction: 'submitForApproval', label: 'Submit' },
           { type: #FOR_ACTION, dataAction: 'approve', label: 'Approve' },
           { type: #FOR_ACTION, dataAction: 'reject', label: 'Reject' }
         ],
         identification: [
           { position: 70, criticality: 'StatusCriticality' },
           { type: #FOR_ACTION, dataAction: 'submitForApproval', label: 'Submit' },
           { type: #FOR_ACTION, dataAction: 'approve', label: 'Approve' },
           { type: #FOR_ACTION, dataAction: 'reject', label: 'Reject' }
         ],
         selectionField: [{ position: 40 }] }
  Status,

  @UI.hidden: true
  StatusText,
  StatusCriticality,

  @EndUserText.label: 'Risk Score'
  @UI: { lineItem: [{ position: 60 }], identification: [{ position: 80 }] }
  RiskScore,

  @EndUserText.label: 'Requested By'
  RequestedBy,
  @EndUserText.label: 'Approved By'
  ApprovedBy,
  @EndUserText.label: 'Created By'
  CreatedBy,
  @EndUserText.label: 'Created At'
  CreatedAt,
  @EndUserText.label: 'Last Changed By'
  LastChangedBy,
  @EndUserText.label: 'Last Changed At'
  LastChangedAt,
  @UI.hidden: true
  LocalLastChangedAt,

  _Roles : redirected to composition child ZC_IAM_REQ_ROLE
}
