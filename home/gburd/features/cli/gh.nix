{ pkgs, ... }:
{
  programs.gh = {
    enable = true;
    extensions = with pkgs; [ gh-markdown-preview ];
    settings = {
      git_protocol = "ssh";
      prompt = "enabled";
    };
  };
  home.persistence = {
    "/persist/home/gburd".directories = [ ".config/gh" ];
  };
}
