{ pkgs, ... }:
{
  programs.gh = {
    enable = true;
    extensions = with pkgs; [ gh-markdown-preview ];
    # Provides the git credential helper for github.com / gist.github.com
    # (replaces the hardcoded `gh auth git-credential` lines that lived in
    # the old hand-maintained ~/.gitconfig).
    gitCredentialHelper.enable = true;
    # Don't manage settings declaratively - let gh manage its own config
    # This allows `gh auth login` and other commands to write to config.yml
    # After first setup, you can manually configure:
    #   gh config set git_protocol ssh
    #   gh config set prompt enabled
  };
}
