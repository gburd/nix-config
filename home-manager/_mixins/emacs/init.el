
;; Added by Package.el.  This must come before configurations of
;; installed packages.  Don't delete this line.  If you don't want it,
;; just comment it out by adding a semicolon to the start of the line.
;; You may delete these explanatory comments.
(package-initialize)

(require 'org)
(require 'ob-tangle)
(org-babel-load-file (expand-file-name "burd.org" user-emacs-directory))
(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(package-selected-packages
   (quote
    (yaml-mode writegood-mode web-mode toml-mode terraform-mode solarized-theme sml-mode smex scala-mode rvm rust-mode restclient python-pep8 python-mode puppet-mode php-mode pastebin paredit o-blog nodejs-repl nixos-options nix-mode multi-web-mode marmalade markdown-mode magit lua-mode intellij-theme htmlize haskell-mode haml-mode hackernews graphviz-dot-mode google-this google-c-style go-mode gist flycheck-rust flycheck-pos-tip flycheck-ocaml flycheck-google-cpplint flycheck-cask flx-isearch flx-ido feature-mode erlang eredis elixir-mode elixir-mix deft csharp-mode company-cmake company-c-headers color-theme-sanityinc-tomorrow coffee-mode cmake-mode clojure-mode autopair ag ac-slime))))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )
