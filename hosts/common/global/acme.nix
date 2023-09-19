{ lib, ... }:
{
  # Enable acme for usage with nginx vhosts
  security.acme = {
    defaults.email = "greg+acme@burd.me";
    acceptTerms = true;
  };

  environment.persistence = {
    "/persist" = {
      directories = [
        "/var/lib/acme"
      ];
    };
  };
}
