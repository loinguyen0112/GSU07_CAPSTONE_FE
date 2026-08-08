managed implementation in class zbp_i_iam_lreq_hdr unique;
strict ( 2 );
with draft;

define behavior for ZI_IAM_LREQ_HDR alias Request
persistent table ziam_lreq_hdr2
draft table ziam_lreq_h_d
lock master
total etag LocalLastChangedAt
authorization master ( global, instance )
etag master LastChangedAt
{
  create;
  update ( features : instance );
  delete ( features : instance );

  association _Roles { create; with draft; }

  draft action Edit;
  draft action Activate;
  draft action Discard;
  draft action Resume;

  draft determine action Prepare
  {
    validation validateEmail;
    validation validateDepartment;
    validation validateJoiner;
  }

  field ( numbering : managed, readonly ) ReqUuid;
  field ( readonly ) ReqId, Status, RiskScore, RequestedBy, ApprovedBy, ApprovalReason,
    FfGrantStatus, FfStartAt, FfEndAt,
    CreatedAt, CreatedBy, LastChangedAt, LastChangedBy, LocalLastChangedAt;
  field ( mandatory ) TargetUser;

  validation validateEmail on save { field ReqType, Email; create; update; }
  validation validateDepartment on save { field ReqType, Department; create; update; }
  validation validateJoiner on save { field ReqType, TargetUser; create; update; }

  action ( features : instance ) submitForApproval result [1] $self;
  action ( features : instance ) approve parameter ZI_IAM_APPROVE_PARAM result [1] $self;
  action ( features : instance ) reject result [1] $self;
  action checkSod result [0..*] ZI_IAM_SOD_ACTION_RESULT;
  action getApprovalRationale result [1] ZI_IAM_APPROVE_PARAM;

  determination setDefaultValues on modify { create; }

  mapping for ziam_lreq_hdr2
  {
    ReqUuid = req_uuid;
    ReqId = req_id;
    ReqType = req_type;
    TargetUser = target_user;
    FirstName = first_name;
    LastName = last_name;
    Department = department;
    Title = title;
    Email = email;
    Telephone = telephone;
    Mobile = mobile;
    Fax = fax;
    Status = status;
    RiskScore = risk_score;
    RequestedBy = requested_by;
    ApprovedBy = approved_by;
    TicketId = ticket_id;
    Reason = reason;
    DurationHours = duration_hours;
    ApprovalReason = approval_reason;
    CreatedBy = created_by;
    CreatedAt = created_at;
    LastChangedBy = last_changed_by;
    LastChangedAt = last_changed_at;
    LocalLastChangedAt = local_last_changed_at;
  }
}

define behavior for ZI_IAM_REQ_ROLE alias Role
persistent table ziam_req_role2
draft table ziam_req_r_d
lock dependent by _Header
authorization dependent by _Header
etag master LastChangedAt
{
  update;
  delete;
  association _Header { with draft; }
  field ( numbering : managed, readonly ) ItemUuid;
  field ( readonly ) ReqUuid, CreatedAt, CreatedBy, LastChangedAt, LastChangedBy, LocalLastChangedAt;
  mapping for ziam_req_role2
  {
    ItemUuid = item_uuid;
    ReqUuid = req_uuid;
    RoleName = role_name;
    ValidFrom = valid_from;
    ValidTo = valid_to;
    CreatedBy = created_by;
    CreatedAt = created_at;
    LastChangedBy = last_changed_by;
    LastChangedAt = last_changed_at;
    LocalLastChangedAt = local_last_changed_at;
  }
}
