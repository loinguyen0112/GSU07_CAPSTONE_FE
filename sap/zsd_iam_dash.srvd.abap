@EndUserText.label: 'IAM Operations Dashboard'
define service ZSD_IAM_DASH {
  expose ZI_IAM_DASH_USERS    as Users;
  expose ZI_IAM_DASH_REQUESTS as Requests;
  expose ZI_IAM_DASH_AUDIT    as AuditEvents;
}
