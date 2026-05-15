{ lib, pkgs, ... }:
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
    package = pkgs.gitFull;
    signing = {
      key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKCqHOIyYwbp42C7MxnRFxOcy+ZE8cNOWdsdvCgVFm1L";
      signByDefault = true;
    };
    settings = {
      user = {
        name = "Greg Burd";
        email = "greg@burd.me";
      };
      init.defaultBranch = "main";
      gpg.format = "ssh";
      "gpg.ssh".program = lib.mkDefault "/opt/1Password/op-ssh-sign";
      commit.gpgsign = true;
      tag.gpgsign = true;
    };
    lfs.enable = true;
    ignores = [
      ".direnv"
      "result"
      # AI tool runtime dirs — contain state/sessions, not source
      ".memelord/"
      ".pi/agent/sessions/"
      ".kiro/sessions/"
      ".claude/settings.local.json"
    ];
  };
}
