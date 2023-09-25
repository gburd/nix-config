_:
{
  users.users.root = {
    hashedPassword = null;
    openssh.authorizedKeys.keys = [ (builtins.readFile ../../../home/gburd/ssh.pub) ];
  };
}
