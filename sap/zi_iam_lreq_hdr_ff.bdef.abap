extension of behavior for ZI_IAM_LREQ_HDR alias Request
{
  association _SodConflicts { }
  action checkSod result [0..*] ZI_IAM_SOD_ACTION_RESULT;
  action getApprovalRationale result [1] ZI_IAM_APPROVE_PARAM;
}
