_:
# The portable half of gburd's git setup: identity, aliases, pull/push policy,
# colours and ignores. Every host gets it through console/default.nix; solnix
# (illumos) hosts import it directly from home-manager/solnix.nix, because
# cli/git.nix also wires gitFull, git-lfs, gitleaks hooks and meld, none of which
# is built for illumos. Host-specific git settings (signing, hooks, difftool)
# stay in cli/git.nix.
{
  programs.git = {
    enable = true;
    settings.alias = {
      a = "add";
      aa = "add --all";
      aaa = "!git a $(git rd)";
      add-nowhitespace = "!git diff -U0 -w --no-color | git apply --cached --ignore-whitespace --unidiff-zero -";
      # amend
      am = "!git cm --amend --no-edit --date=\"$(date +'%Y %D')\"";
      amend = "commit --amend";
      # branch name
      bn = "br --show-current";
      br = "branch";
      ci = "commit";
      co = "checkout";
      cob = "co -b";
      d = "diff";
      dag = "log --graph --format='format:%C(yellow)%h%C(reset) %C(blue)\"%an\" <%ae>%C(reset) %C(magenta)%cr%C(reset)%C(auto)%d%C(reset)%n%s' --date-order";
      dc = "diff --cached";
      di = "diff";
      div = "divergence";
      ds = "d --staged";
      f = "fetch";
      fa = "f --all";
      fast-forward = "merge --ff-only";
      ff = "merge --ff-only";
      files = "show --oneline";
      gn = "goodness";
      gnc = "goodness --cached";
      # generate patch
      gp = "!gitgenpatch() { target=$1; git format-patch $target --stdout | sed -n -e '/^diff --git/,$p' | head -n -3; }; gitgenpatch";
      graph = "log --decorate --oneline --graph";
      h = "!git head";
      head = "!git l -1";
      # shows commit history
      hist = "log --pretty=format:\"%h %ad | %s%d [%an]\" --graph --date=short";
      l = "log --graph --abbrev-commit --date=relative";
      la = "!git l --all";
      lastchange = "log -n 1 -p";
      lg = "log --color --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit --date=relative";
      lol = "log --graph --decorate --pretty=oneline --abbrev-commit";
      lola = "log --graph --decorate --pretty=oneline --abbrev-commit --all";
      mend = "commit --amend --no-edit";
      p = "push";
      # force with lease
      pf = "poh --force-with-lease";
      # FORCEEEE
      pff = "poh --force";
      # push to origin HEAD
      poh = "p origin HEAD";
      pom = "push origin master";
      # push and open pr
      ppr = "!git poh; !git pr";
      # open pr
      pr = "!gh pr create";
      pullff = "pull --ff-only";
      pushall = "!git remote | xargs -L1 git push --all";
      r = "!git --no-pager l -20";
      ra = "!git r --all";
      rb = "rebase";
      rbc = "rebase --continue";
      # gets root directory
      rd = "rev-parse --show-toplevel";
      rh = "rs --hard";
      rho = "!git rh origin/$(git bn)";
      rs = "reset";
      # squash it
      sq = "!gitsq() { git rb -i $(git sr $1) $2; }; gitsq";
      # gets latest shared commit
      sr = "merge-base HEAD";
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
    settings = {
      push.default = "matching";
      pull = {
        rebase = true;
        ff = "only";
      };
      init.defaultBranch = "main";
      user = {
        name = "Greg Burd";
        email = "greg@burd.me";
      };
      color = {
        ui = "auto";
        diff = "auto";
        status = "auto";
        branch = "auto";
      };
      format.pretty = "format:%C(yellow)%h%Creset | %C(green)%ad (%ar)%Creset | %C(blue)%an%Creset | %s";
      push.autoSetupRemote = true;
      branch.autosetuprebase = "always";
      receive.denyCurrentBranch = "warn";
      core.quotepath = false;
    };
    ignores = [
      "*.log"
      "*.out"
      ".DS_Store"
      "bin/"
      "dist/"
      "result"
    ];
  };
}
