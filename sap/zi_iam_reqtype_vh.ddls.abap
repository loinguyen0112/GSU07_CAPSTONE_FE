@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Value Help for Request Type'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.resultSet.sizeCategory: #XS
define view entity ZI_IAM_REQTYPE_VH as select from t000 {
  @ObjectModel.text.element: ['Description']
  @UI.textArrangement: #TEXT_ONLY
  key cast('J' as abap.char(1)) as ReqType,
      cast('Joiner (New Hire)' as abap.char(40)) as Description
} where mandt = $session.client
union all select from t000 {
  key cast('M' as abap.char(1)) as ReqType,
      cast('Mover (Transfer)' as abap.char(40)) as Description
} where mandt = $session.client
union all select from t000 {
  key cast('L' as abap.char(1)) as ReqType,
      cast('Leaver (Termination)' as abap.char(40)) as Description
} where mandt = $session.client
union all select from t000 {
  key cast('F' as abap.char(1)) as ReqType,
      cast('Firefighter Access' as abap.char(40)) as Description
} where mandt = $session.client
