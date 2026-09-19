@EndUserText.label: 'Service Definition for Lifecycle Manager'
define service ZSD_IAM_LIFECYCLE {
  expose ZC_IAM_LREQ_HDR as Request;
  expose ZC_IAM_REQ_ROLE as RoleItem;
  expose ZI_IAM_FF_GRANT_REQ as FirefighterGrant;
  expose ZI_IAM_FF_ROLE_VH as FirefighterRole;
}
