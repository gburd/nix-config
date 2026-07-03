{ pkgs, ... }:
# Typora — minimal WYSIWYG Markdown editor/reader (unfree). GUI hosts only
# (floki, arnold). Imported from those hosts' user config.
{
  home.packages = [ pkgs.typora ];
}
