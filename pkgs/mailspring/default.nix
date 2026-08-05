{ mailspringBase, asar }:

# Mailspring with a randomized outgoing Message-ID.
#
# WHY: stock Mailspring stamps every draft's Message-ID header as
# `<UUID>@getmailspring.com`, which advertises the client on every message
# you send (e.g. to the pgsql-hackers list). This override rewrites that to
# `<UUID>@burd.me` so the header leaks nothing about the client. (Not a
# bare `<UUID>@` with no domain -- a Message-ID needs a valid id-right per
# RFC 5322, and a missing/non-FQDN right side hurts deliverability / spam
# scoring on lists like pgsql-hackers. Using your own real domain is both
# valid and non-identifying. Not `.local` either -- that TLD is itself a
# mild "avoiding a real domain" tell.)
#
# HOW: nixpkgs' mailspring is a BINARY package (prebuilt .deb) -- there's no
# TypeScript source to patch at build time, so the original
# pkgs/mailspring/randomize-message-id.patch (a source diff against
# draft-factory.ts) can't apply. But the .deb ships the compiled JS
# unminified inside app.asar, so we unpack the asar, do the same
# substitution on src/flux/stores/draft-factory.js, and repack. Same net
# effect as the patch, applied one layer down (compiled JS, not TS source).
mailspringBase.overrideAttrs (old: {
  nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ asar ];

  # Run after autoPatchelf/wrapGApps have done their thing. Extract ->
  # substitute -> repack the asar in place. The `\`...\`` template literal
  # in the compiled JS is matched exactly (verified against the shipped
  # 1.21.1 bundle); if a future mailspring bump changes that line, this
  # sed becomes a no-op (harmless) and the header reverts to upstream --
  # re-verify the line then.
  postFixup = (old.postFixup or "") + ''
    asarFile="$out/share/mailspring/resources/app.asar"
    work="$(mktemp -d)"
    asar extract "$asarFile" "$work"
    target="$work/src/flux/stores/draft-factory.js"
    if grep -q '@getmailspring.com`' "$target"; then
      substituteInPlace "$target" \
        --replace-fail \
          '`''${crypto.randomUUID().toUpperCase()}@getmailspring.com`' \
          '`''${crypto.randomUUID().toUpperCase()}@burd.me`'
      asar pack "$work" "$asarFile"
      echo "mailspring: randomized outgoing Message-ID domain (was @getmailspring.com)"
    else
      echo "mailspring: WARNING @getmailspring.com Message-ID line not found -- upstream changed it; leaving asar untouched" >&2
    fi
    rm -rf "$work"
  '';
})
