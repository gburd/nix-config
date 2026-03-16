{ pkgs, ... }:
{
  home.packages = with pkgs; [
    act # Run GitHub Actions locally with Docker
  ];

  # Optional: Configure act defaults
  xdg.configFile."act/actrc".text = ''
    # Use medium-sized runner image (balance between size and compatibility)
    -P ubuntu-latest=catthehacker/ubuntu:act-latest
    -P ubuntu-22.04=catthehacker/ubuntu:act-22.04

    # Reuse containers between runs (faster)
    --reuse

    # Use GitHub API token from environment
    # Set GITHUB_TOKEN in your shell: export GITHUB_TOKEN=ghp_...
  '';
}
