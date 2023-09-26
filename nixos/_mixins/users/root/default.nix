_:
{
  users.users.root = {
    hashedPassword = null;
    openssh.authorizedKeys.keys = [ (builtins.readFile ../../../../home-manager/_mixins/users/gburd/ssh.pub) ];
  };
}
