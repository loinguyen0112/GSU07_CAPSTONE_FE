unmanaged implementation in class zbp_i_rusers02 unique;
strict ( 2 );

define behavior for ZI_RUSERS02 alias User
  lock master
  authorization master ( global )
{
  action lockUser result [1] $self;
  action unlockUser result [1] $self;
  action checkRoles result [1] $self;
  action checkSod result [1] $self;

}
