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
    aliases = {
      aa = "add --all";
      add-nowhitespace = "!git diff -U0 -w --no-color | git apply --cached --ignore-whitespace --unidiff-zero -";
      amend = "commit --amend";
      ci = "commit";
      co = "checkout";
      dag = "log --graph --format='format:%C(yellow)%h%C(reset) %C(blue)\"%an\" <%ae>%C(reset) %C(magenta)%cr%C(reset)%C(auto)%d%C(reset)%n%s' --date-order";
      dc = "diff --cached";
      di = "diff";
      div = "divergence";
      fa = "fetch --all";
      fast-forward = "merge --ff-only";
      ff = "merge --ff-only";
      files = "show --oneline";
      gn = "goodness";
      gnc = "goodness --cached";
      graph = "log --decorate --oneline --graph";
      h = "!git head";
      head = "!git l -1";
      l = "log --graph --abbrev-commit --date=relative";
      la = "!git l --all";
      lastchange = "log -n 1 -p";
      lg = "log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit --date=relative";
      lol = "log --graph --decorate --pretty=oneline --abbrev-commit";
      lola = "log --graph --decorate --pretty=oneline --abbrev-commit --all";
      mend = "commit --amend --no-edit";
      pom = "push origin master";
      pullff = "pull --ff-only";
      pushall = "!git remote | xargs -L1 git push --all";
      r = "!git --no-pager l -20";
      ra = "!git r --all";
      st = "status --short";
      subdate = "submodule update --init --recursive";
      sync = "pull --rebase";
      unadd = "reset --";
      unedit = "checkout --";
      unrm = "checkout --";
      unstage = "reset HEAD";
      unstash = "stash pop";
      update = "merge --ff-only origin/master";
    };
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
