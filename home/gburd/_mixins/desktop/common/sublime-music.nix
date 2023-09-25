{ pkgs, ... }: {
  home.packages = [ pkgs.sublime-music ];
  home.persistence = {
    "/persist/home/gburd".directories = [ ".config/sublime-music" ];
  };
}
