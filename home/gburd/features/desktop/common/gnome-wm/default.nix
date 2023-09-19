{ pkgs, ... }:
{
  imports = [];

  home.packages = with pkgs; [
    gtk3 # For gtk-launch
    xdg-utils-spawn-terminal # Patched to open terminal
  ];

#   environment.gnome.excludePackages = (with pkgs; [
#     gnome-photos
#     gnome-tour
#   ]) ++ (with pkgs.gnome; [
#     cheese # webcam tool
#     gnome-music
#     gedit # text editor
#     epiphany # web browser
#     geary # email reader
#     gnome-characters
#     tali # poker game
#     iagno # go game
#     hitori # sudoku game
#     atomix # puzzle game
#     yelp # Help view
#     gnome-contacts
#     gnome-initial-setup
#   ]);
#   programs.dconf.enable = true;
#   environment.systemPackages = with pkgs; [
#     gnome.gnome-tweaks
#   ]
# };

  home.sessionVariables = {
  };
}
