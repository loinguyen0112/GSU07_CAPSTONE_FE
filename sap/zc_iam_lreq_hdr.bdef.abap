projection;
strict ( 2 );
use draft;

define behavior for ZC_IAM_LREQ_HDR alias Request
{
  use create;
  use update;
  use delete;
  use action submitForApproval;
  use action approve;
  use action reject;
  use action checkSod;
  use action getApprovalRationale;
  use action Edit;
  use action Activate;
  use action Discard;
  use action Resume;
  use action Prepare;
  use association _Roles { create; with draft; }
}

define behavior for ZC_IAM_REQ_ROLE alias RoleItem
{
  use update;
  use delete;
  use association _Header { with draft; }
}
