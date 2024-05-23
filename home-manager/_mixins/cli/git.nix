{ pkgs, config, ... }:
let
  ssh = "${pkgs.openssh}/bin/ssh";

  git-gburd = pkgs.writeShellScriptBin "git-gburd" ''
    repo="$(git remote -v | grep git@burd.me | head -1 | cut -d ':' -f2 | cut -d ' ' -f1)"
    # Add a .git suffix if it's missing
    if [[ "$repo" != *".git" ]]; then
      repo="$repo.git"
    fi

    if [ "$1" == "init" ]; then
      if [ "$2" == "" ]; then
        echo "You must specify a name for the repo"
        exit 1
      fi
      ${ssh} -A git@burd.me << EOF
        git init --bare "$2.git"
        git -C "$2.git" branch -m main
    EOF
      git remote add origin git@burd.me:"$2.git"
    elif [ "$1" == "ls" ]; then
      ${ssh} -A git@burd.me ls
    else
      ${ssh} -A git@burd.me git -C "/srv/git/$repo" $@
    fi
  '';
in
{
  home.packages = [ git-gburd ];
  programs.git = {
    enable = true;
    package = pkgs.gitAndTools.gitFull;
    userName = "Greg Burd";
    userEmail = "greg@burd.me";
    signing = {
      key = "D4BB42BE729AEFBD2EFEBF8822931AF7895E82DF";
      signByDefault = true;
    };
    extraConfig = {
      init.defaultBranch = "main";
      gpg.program = "${config.programs.gpg.package}/bin/gpg2";
    };
    lfs.enable = true;
    ignores = [ ".direnv" "result" ];
  };
}
