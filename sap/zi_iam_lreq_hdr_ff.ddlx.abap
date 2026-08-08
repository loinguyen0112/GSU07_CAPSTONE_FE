@EndUserText.label: 'Lifecycle Firefighter extension'
extend view entity ZI_IAM_LREQ_HDR with {
  ticket_id       as TicketId,
  reason          as Reason,
  duration_hours  as DurationHours,
  approval_reason as ApprovalReason,
  _FfGrant.GrantStatus as FfGrantStatus,
  _FfGrant.StartAt     as FfStartAt,
  _FfGrant.EndAt       as FfEndAt,
  _FfGrant : association [0..1] to ZI_IAM_FF_GRANT_REQ
    on $projection.ReqUuid = _FfGrant.RequestUuid
}
