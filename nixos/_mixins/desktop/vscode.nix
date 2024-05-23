args@{ pkgs, lib, ... }:
let
  codeServer = if builtins.hasAttr "codeServer" args then args.codeServer else { enable = false; };

  languages = if builtins.hasAttr "languages" args then args.languages else { };

  getLangOr = key: default: !!(if builtins.hasAttr key languages then languages [ key ] else default);

  getListIf = isEnabled: list: if isEnabled then list else [ ];

  # NOTE: regenerate or update using the script in this directory
  ext = {
    bash-debug = {
      name = "bash-debug";
      publisher = "rogalmic";
      version = "0.3.9";
      sha256 = "0n7lyl8gxrpc26scffbrfczdj0n9bcil9z83m4kzmz7k5dj59hbz";
    };
    bash-ide-vscode = {
      name = "bash-ide-vscode";
      publisher = "mads-hartmann";
      version = "1.41.0";
      sha256 = "0gc4fk9j202xgahj1jy9p20fqxkfbldy4d0gbir5x3i7hq2ahml2";
    };
    cmake-tools = {
      name = "cmake-tools";
      publisher = "ms-vscode";
      version = "1.18.39";
      sha256 = "16wywsx5md3zkaj42vnp8bjpvv5pp4bwm9ll3gxbb0jhs1dwz7fc";
    };
    code-spell-checker = {
      name = "code-spell-checker";
      publisher = "streetsidesoftware";
      version = "3.0.1";
      sha256 = "0i76gf7zr0j4dr02zmxwfphk6yy8rvlj9rzq3k8pvnlfzkmh9ri9";
    };
    copilot = {
      name = "copilot";
      publisher = "github";
      version = "1.194.886";
      sha256 = "0qvsij109i1n89xl6clr4010r6q71pk4xhsyrzr1nyqggqwqhhpn";
    };
    cpptools = {
      name = "cpptools";
      publisher = "ms-vscode";
      version = "1.20.5";
      sha256 = "1j1a8ni5gihpw7zi8c6pg0l2n9yqbk369s3mywgz7dj8ykx7q8xl";
    };
    cpptools-extension-pack = {
      name = "cpptools-extension-pack";
      publisher = "ms-vscode";
      version = "1.3.0";
      sha256 = "11fk26siccnfxhbb92z6r20mfbl9b3hhp5zsvpn2jmh24vn96x5c";
    };
    debian-vscode = {
      name = "debian-vscode";
      publisher = "dawidd6";
      version = "0.1.2";
      sha256 = "0vzqwbd1qck9m0ip6vg995xz3x15x68jfly1f5zp1dpmaw8rmc0f";
    };
    editorconfig = {
      name = "editorconfig";
      publisher = "editorconfig";
      version = "0.16.4";
      sha256 = "0fa4h9hk1xq6j3zfxvf483sbb4bd17fjl5cdm3rll7z9kaigdqwg";
    };
    font-switcher = {
      name = "font-switcher";
      publisher = "evan-buss";
      version = "4.1.0";
      sha256 = "1ijn55n6866hagrpaccjb1fc36xmjw5sclydgq8pkvyn1xyd8i9a";
    };
    gitlens = {
      name = "gitlens";
      publisher = "eamodio";
      version = "2024.5.2305";
      sha256 = "1i24zbrf8d35mmc3ajyah8fxwdkjvz89c88i4iac4y3ahd5kpdzf";
    };
    go = {
      name = "go";
      publisher = "golang";
      version = "0.41.4";
      sha256 = "03gxgcvjk5plzkk7gjsrrck1kszzbzswkbcr33m3qlkyz4iw9nly";
    };
    grammarly = {
      name = "grammarly";
      publisher = "znck";
      version = "0.25.0";
      sha256 = "048bahfaha3i6sz1b5jkyhfd2aiwgpkmyy2i7hlzc45g1289827z";
    };
    language-hugo-vscode = {
      name = "language-hugo-vscode";
      publisher = "budparr";
      version = "1.3.1";
      sha256 = "16bchjx895jg0avgbg2s13kij1i8h2rma2vbks4w6vy00bz7rnpm";
    };
    linux-desktop-file = {
      name = "linux-desktop-file";
      publisher = "nico-castell";
      version = "0.0.21";
      sha256 = "0d2pfby72qczljzw1dk2rsqkqharl2sbq3g31zylz0rx73cvxb72";
    };
    makefile-tools = {
      name = "makefile-tools";
      publisher = "ms-vscode";
      version = "0.10.7";
      sha256 = "148c15friprfj1bwcalz3divrjnq283pgz9984aklznkb3fzas06";
    };
    markdown-all-in-one = {
      name = "markdown-all-in-one";
      publisher = "yzhang";
      version = "3.6.2";
      sha256 = "1n9d3qh7vypcsfygfr5rif9krhykbmbcgf41mcjwgjrf899f11h4";
    };
    nix-ide = {
      name = "nix-ide";
      publisher = "jnoortheen";
      version = "0.3.1";
      sha256 = "1cpfckh6zg8byi6x1llkdls24w9b0fvxx4qybi9zfcy5gc60r6nk";
    };
    non-breaking-space-highlighter = {
      name = "non-breaking-space-highlighter";
      publisher = "viktorzetterstrom";
      version = "0.0.3";
      sha256 = "1v7x973bbywqdpkslvwn5nh2fpxiq82cq4d9g7g0y2vzac2r3s5p";
    };
    partial-diff = {
      name = "partial-diff";
      publisher = "ryu1kn";
      version = "1.4.3";
      sha256 = "0x3lkvna4dagr7s99yykji3x517cxk5kp7ydmqa6jb4bzzsv1s6h";
    };
    prettier-vscode = {
      name = "prettier-vscode";
      publisher = "esbenp";
      version = "10.4.0";
      sha256 = "1iy7i0yxnhizz40llnc1dk9q8kk98rz6ki830sq7zj3ak9qp9vzk";
    };
    pubspec-assist = {
      name = "pubspec-assist";
      publisher = "jeroen-meijer";
      version = "2.3.2";
      sha256 = "1zdv8i6i4hka536i52qbqpmghs6jyn22vgzxp7jfnvxvx9nirjgq";
    };
    python = {
      name = "python";
      publisher = "ms-python";
      version = "2024.7.11371014";
      sha256 = "0s21jdpdcwy7pnmzlqk9l8h71yh7wg1idhj6zgqk91xa06dhq060";
    };
    remote-ssh-edit = {
      name = "remote-ssh-edit";
      publisher = "ms-vscode-remote";
      version = "0.47.2";
      sha256 = "1hp6gjh4xp2m1xlm1jsdzxw9d8frkiidhph6nvl24d0h8z34w49g";
    };
    rust-analyzer = {
      name = "rust-analyzer";
      publisher = "rust-lang";
      version = "0.3.1386";
      sha256 = "qttgUVpoYNEg2+ArYxnEHwM4AbChQiB6/JW46+cq7/w=";
    };
    shellcheck = {
      name = "shellcheck";
      publisher = "timonwong";
      version = "0.37.1";
      sha256 = "sha256-JSS0GY76+C5xmkQ0PNjt2Nu/uTUkfiUqmPL51r64tl0=";
    };
    simple-rst = {
      name = "simple-rst";
      publisher = "trond-snekvik";
      version = "1.5.4";
      sha256 = "1js1489nd9fycvpgh39mwzpbqm28qi4gzi68443v3vhw3dsg4wjv";
    };
    systemd-unit-file = {
      name = "systemd-unit-file";
      publisher = "coolbear";
      version = "1.0.6";
      sha256 = "0sc0zsdnxi4wfdlmaqwb6k2qc21dgwx6ipvri36x7agk7m8m4736";
    };
    vala = {
      name = "vala";
      publisher = "prince781";
      version = "1.0.8";
      sha256 = "sha256-IuIb7vLNiE3rzVHOsjInaYLzNYORbwabQq0bfaPLlqc=";
    };
    vscode-docker = {
      name = "vscode-docker";
      publisher = "ms-azuretools";
      version = "1.29.1";
      sha256 = "0zba6g0cw2h42gfvrlx0x2axlj61hkrfjfg5kyd14fqzi4n9jmxs";
    };
    vscode-front-matter = {
      name = "vscode-front-matter";
      publisher = "eliostruyf";
      version = "8.4.0";
      sha256 = "sha256-L0PbZ4HxJAlxkwVcZe+kBGS87yzg0pZl89PU0aUVYzY=";
    };
    vscode-github-actions = {
      name = "vscode-github-actions";
      publisher = "github";
      version = "0.26.2";
      sha256 = "16kp1yxs798jp8ffqq3ixm3pyz4f3wgdkdyjpjy94ppqp4aklixh";
    };
    vscode-icons = {
      name = "vscode-icons";
      publisher = "vscode-icons-team";
      version = "12.7.0";
      sha256 = "1w30gd0chf2c26a9c426ghs7gmss9dk9yzlrab51ydwhfkkd4hxb";
    };
    vscode-mdx = {
      name = "vscode-mdx";
      publisher = "unifiedjs";
      version = "1.8.6";
      sha256 = "177yjm8dhjjgmwww00sqi0fk1clajkdyy2nypi8413xv6cm14c71";
    };
    vscode-mdx-preview = {
      name = "vscode-mdx-preview";
      publisher = "xyc";
      version = "0.3.3";
      sha256 = "1i65l6xrzh3if4x3bj012rrdk6lwyrmlpgdqml4p53048nm09b1q";
    };
    vscode-neovim = {
      name = "vscode-neovim";
      publisher = "asvetliakov";
      version = "1.12.0";
      sha256 = "09xyb2i1va0yq45ymk20v9cxjnc02xlfvm1rm8cialq19xl3h0m2";
    };
    vscode-power-mode = {
      name = "vscode-power-mode";
      publisher = "hoovercj";
      version = "3.0.2";
      sha256 = "sha256-ZE+Dlq0mwyzr4nWL9v+JG00Gllj2dYwL2r9jUPQ8umQ=";
    };
    vscode-pylance = {
      name = "vscode-pylance";
      publisher = "ms-python";
      version = "2024.5.101";
      sha256 = "0yp0dlq2q9yvv5vhpxfmpbrdgcy61i9r1ilknhni29nlg86mqbbv";
    };
    vscode-yaml = {
      name = "vscode-yaml";
      publisher = "redhat";
      version = "1.14.0";
      sha256 = "0pww9qndd2vsizsibjsvscz9fbfx8srrj67x4vhmwr581q674944";
    };
    vsliveshare = {
      name = "vsliveshare";
      publisher = "ms-vsliveshare";
      version = "1.0.5918";
      sha256 = "1m4mpy6irj3vzjw6mzmjjp6appgf000zfhmkjwxw65sl4wmjckaf";
    };
    xml = {
      name = "xml";
      publisher = "dotjoshjohnson";
      version = "2.5.1";
      sha256 = "1v4x6yhzny1f8f4jzm4g7vqmqg5bqchyx4n25mkgvw2xp6yls037";
    };
  };


  g = {
    ai = getLangOr "ai" false;
    cpp = getLangOr "cpp" true;
    diff = getLangOr "diff" true;
    docker = getLangOr "docker" true;
    editorconfig = getLangOr "editorconfig" true;
    elm = getLangOr "elm" false;
    fun = getLangOr "fun" false;
    github = getLangOr "github" false;
    gitlens = getLangOr "gitlens" false;
    go = getLangOr "go" false;
    hugo = getLangOr "hugo" false;
    icons = getLangOr "icons" true;
    js = getLangOr "js" true;
    linux = getLangOr "linux" false;
    nix = getLangOr "nix" true;
    php = getLangOr "php" false;
    prisma = getLangOr "prisma" true;
    python = getLangOr "python" true;
    rust = getLangOr "rust" false;
    ssh = getLangOr "ssh" false;
    text = getLangOr "text" true;
    vala = getLangOr "vala" false;
    xml = getLangOr "xml" true;
    yaml = getLangOr "yaml" true;
  };
in
{
  imports = lib.optional codeServer.enable ../services/vscode-server.nix
  ;

  environment.systemPackages = with pkgs; [
    (vscode-with-extensions.override {
      inherit (trunk) vscode;
      vscodeExtensions = with unstable.vscode-extensions;
        # globally enabled extensions
        getListIf g.cpp [ ms-vscode.cpptools ms-vscode.cpptools-extension-pack ms-vscode.cmake-tools ms-vscode.makefile-tools ]
        ++ getListIf g.diff [ ryu1kn.partial-diff ]
        ++ getListIf g.docker [ ms-azuretools.vscode-docker ]
        ++ getListIf g.editorconfig [ editorconfig.editorconfig ]
        ++ getListIf g.elm [ elmtooling.elm-ls-vscode ]
        ++ getListIf g.github [ github.vscode-github-actions github.copilot ]
        ++ getListIf g.gitlens [ eamodio.gitlens ]
        ++ getListIf g.go [ golang.go ]
        ++ getListIf g.icons [ vscode-icons-team.vscode-icons ]
        ++ getListIf g.js [ esbenp.prettier-vscode ]
        ++ getListIf g.linux [ coolbear.systemd-unit-file timonwong.shellcheck mads-hartmann.bash-ide-vscode ]
        ++ getListIf g.nix [ bbenoist.nix jnoortheen.nix-ide ]
        ++ getListIf g.php [ bmewburn.vscode-intelephense-client ]
        ++ getListIf g.prisma [ prisma.prisma ]
        ++ getListIf g.python [ ms-python.python ms-python.vscode-pylance ]
        ++ getListIf g.ssh [ ms-vscode-remote.remote-ssh ]
        ++ getListIf g.text [ streetsidesoftware.code-spell-checker yzhang.markdown-all-in-one ]
        ++ getListIf g.xml [ dotjoshjohnson.xml ]
        ++ getListIf g.yaml [ redhat.vscode-yaml ]

        # The most simple way to calculate a package's SHA256 is to simply
        # copy over an invalid SHA256 and the nixos-rebuild will fail,
        # with output for the specified and actual hash values.  Or,
        # SHA=$(nix-hash --flat --base32 --type sha256 "$EXTTMP/$N.zip")
        # see: https://t.ly/Akd1I
        ++ (pkgs.unstable.vscode-utils.extensionsFromVscodeMarketplace
          # globally enabled extensions
          [ ext.non-breaking-space-highlighter ext.vscode-neovim
            # TODO: the following is a work-around for the option-based
            # method below which doesn't seem to work at the moment.
            ext.bash-debug ext.gitlens ext.copilot ext.vscode-github-actions
            ext.bash-ide-vscode ext.shellcheck ext.grammarly
          ]
        ++ getListIf g.ai [ ext.copilot ]
        ++ getListIf g.cpp [ ]
        ++ getListIf g.diff [ ]
        ++ getListIf g.docker [ ]
        ++ getListIf g.editorconfig [ ]
        ++ getListIf g.elm [ ]
        ++ getListIf g.fun [ ext.vscode-power-mode ]
        ++ getListIf g.github [ ]
        ++ getListIf g.gitlens [ ]
        ++ getListIf g.go [ ]
        ++ getListIf g.hugo [ ext.language-hugo-vscode ]
        ++ getListIf g.icons [ ]
        ++ getListIf g.js [ ]
        ++ getListIf g.linux [ ext.linux-desktop-file ext.bash-debug ]
        ++ getListIf g.nix [ ]
        ++ getListIf g.php [ ]
        ++ getListIf g.python [ ]
        ++ getListIf g.rust [ ext.rust-analyzer ]
        ++ getListIf g.ssh [ ext.remote-ssh-edit ]
        # TODO: Determine root cause of manifest issues
        # ++ getListIf g.text [ext.simple-rst ext.vscode-mdx ext.vscode-mdx-preview]
        ++ getListIf g.xml [ ]
        ++ getListIf g.yaml [ ]
        )
      ;
    })
  ];

  # May require the service to be enable/started for the user
  # - systemctl --user enable auto-fix-vscode-server.service --now
}
# unstable.vscode-extensions.ms-vsliveshare.vsliveshare
