{ pkgs, ... }: {
  imports = [
    ./act.nix
    ./bash.nix
    ./bat.nix
    ./direnv.nix
    ./gh.nix
    ./git.nix
    ./gpg.nix
    #./jujutsu.nix
    ./nix-index.nix
    ./pfetch.nix
    ./ranger.nix
    ./screen.nix
    ./ssh.nix
    ./tea.nix
  ];

  # Wrapped in lib/evaluates.nix so packages that cannot evaluate on this
  # platform (riscv64 has no GHC, no Chromium, no qtwebengine) drop out
  # instead of failing the whole generation. A no-op on x86_64/aarch64.
  home.packages = import ../../../lib/evaluates.nix (with pkgs; [
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
    s5cmd # Fast S3/object-store client; the mc replacement (aliased to `mc`)
    trash-cli # `trash`/`trash-empty`/`trash-list` -- the rm -rf replacement the steering mandates (Linux + darwin)
    timer # To help with my ADHD paralysis

    nil # Nix LSP
    nixfmt # Nix formatter (was nixfmt-rfc-style; that alias is now deprecated)
    nix-inspect # See which pkgs are in your PATH

    tly # Tally counter
    umami # Filter log streams down to the anomalous messages

    kubectl
    k9s
    kubernetes-helm
    kind
    terraform
    terraform-ls
    nerdctl
  ]);
}
