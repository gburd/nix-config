{ pkgs, ... }: {
  imports = [
    ./bash.nix
    ./bat.nix
    ./direnv.nix
    ./fish.nix
    ./gh.nix
    ./git.nix
    ./gpg.nix
    #./jujutsu.nix
    ./nix-index.nix
    ./pfetch.nix
    ./ranger.nix
    ./screen.nix
    ./ssh.nix
  ];

  home.packages = with pkgs; [
    comma # Install and run programs by sticking a "," (comma) before them
    distrobox # Nice escape hatch, integrates docker images with my environment

    bc # Calculator
    bottom # System viewer
    ncdu # TUI disk usage
    eza # Better ls
    ripgrep # Better grep
    fd # Better find
    curl # cURL
    httpie # Better curl
    diffsitter # Better diff
    jq # JSON pretty printer and manipulator
    timer # To help with my ADHD paralysis

    nil # Nix LSP
    nixfmt-rfc-style # Nix formatter
    nix-inspect # See which pkgs are in your PATH

    ltex-ls # Spell checking LSP

    tly # Tally counter

    kubectl
    k9s
    kubernetes-helm
    kind
    terraform
    terraform-ls
    nerdctl
  ];
}
