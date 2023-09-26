{ pkgs, config, ... }:
let
  ssh = "${pkgs.openssh}/bin/ssh";

  git-m7 = pkgs.writeShellScriptBin "git-m7" ''
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
  home.packages = [ git-m7 ];
  programs.git = {
    enable = true;
    package = pkgs.gitAndTools.gitFull;
    aliases = {
      pushall = "!git remote | xargs -L1 git push --all";
      graph = "log --decorate --oneline --graph";
      add-nowhitespace = "!git diff -U0 -w --no-color | git apply --cached --ignore-whitespace --unidiff-zero -";
      fast-forward = "merge --ff-only";
    };
    userName = "Greg Burd";
    userEmail = "gburd@symas.com";
    extraConfig = {
      init.defaultBranch = "main";
      user.signing.key = "1FC1E7793410DE46";
      commit.gpgSign = true;
      gpg.program = "${config.programs.gpg.package}/bin/gpg2";
    };
    lfs.enable = true;
    ignores = [ ".direnv" "result" ];
  };
}
