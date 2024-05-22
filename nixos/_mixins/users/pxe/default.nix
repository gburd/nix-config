{ sshMatrix, ... }:
{
  users.users.pxe = {
    # mkpasswd -m sha-512
    hashedPassword = "$6$P.52FPzkhqEhwBXH$YAdjuSoboOkgQs6y5JBKOyknQ8Hb.hgsfTPv8ehuI9oyTUbgCp8fD2TsqpDQM8qanmounKKitrcFg4b7aY7Ap0";
    openssh.authorizedKeys.keys = sshMatrix.groups.privileged_users;
  };
}
