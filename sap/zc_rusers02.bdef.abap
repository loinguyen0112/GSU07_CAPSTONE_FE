projection;
strict ( 2 );

define behavior for ZC_RUSERS02 alias User
{
  use action lockUser;
  use action unlockUser;
  use action checkRoles;
  use action checkSod;
}
