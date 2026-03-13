# tea - Official CLI for Gitea/Forgejo (works with Codeberg.org)
# Similar to GitHub CLI but for Gitea-based forges

{ pkgs, ... }:

{
  home.packages = with pkgs; [
    tea  # Gitea/Forgejo CLI
  ];

  # tea manages its own config at ~/.config/tea/config.yml
  # Configuration is done imperatively after installation
}
