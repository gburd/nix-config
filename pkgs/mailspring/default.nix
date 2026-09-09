{ mailspringBase, asar }:

# Mailspring, patched at the asar layer for two annoyances:
#   1. Message-ID header -- non-advertising (see below).
#   2. the "Mailspring" sidebar mailbox -- renamed to "Other".
#
# WHY (1): stock Mailspring stamps every draft's Message-ID header as
# `<UUID>@getmailspring.com`, which advertises the client on every message
# you send (e.g. to the pgsql-hackers list). This override rewrites the
# domain to the SENDING ACCOUNT's own domain (account.defaultMe().email's
# part after @), so the header looks like an ordinary Message-ID from your
# mail provider and leaks nothing about the client. Deriving it from the
# sender (rather than hardcoding a domain, or dropping the domain entirely)
# keeps it RFC 5322-valid -- a Message-ID needs a real id-right, and a bare
# `<UUID>@`/no-domain form hurts deliverability + spam scoring on lists.
#
# HOW: nixpkgs' mailspring is a BINARY package (prebuilt .deb) -- there's no
# TypeScript source to patch at build time. But the .deb ships the compiled
# JS unminified inside app.asar, so we unpack the asar, rewrite the one
# headerMessageId line in src/flux/stores/draft-factory.js, and repack.
mailspringBase.overrideAttrs (old: {
  nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ asar ];

  # Run after autoPatchelf/wrapGApps have done their thing. Extract ->
  # rewrite -> repack the asar in place. The `\`...\`` template literal is
  # matched exactly (verified against the shipped 1.21.1 bundle); if a
  # future mailspring bump changes that line, the guard below warns and
  # leaves the asar untouched -- re-verify the line then.
  #
  # `account` is in scope in createDraft (const account =
  # this._accountForNewDraft()); defaultMe() returns the sender Contact, so
  # (...email.split('@')[1] || 'localhost') is its domain, with a valid
  # fallback if the address somehow lacks an @.
  postFixup = (old.postFixup or "") + ''
    asarFile="$out/share/mailspring/resources/app.asar"
    work="$(mktemp -d)"
    asar extract "$asarFile" "$work"
    changed=0

    # (1) Message-ID domain -> derived from the sending account (see header).
    mid="$work/src/flux/stores/draft-factory.js"
    if grep -q '@getmailspring.com`' "$mid"; then
      substituteInPlace "$mid" \
        --replace-fail \
          '`''${crypto.randomUUID().toUpperCase()}@getmailspring.com`' \
          '`''${crypto.randomUUID().toUpperCase()}@''${(account.defaultMe().email.split("@")[1] || "localhost")}`'
      changed=1
      echo "mailspring: Message-ID domain now derived from the sending account (was @getmailspring.com)"
    else
      echo "mailspring: WARNING @getmailspring.com Message-ID line not found -- upstream changed it; leaving it" >&2
    fi

    # (2) Sidebar label: the bare "Mailspring" container folder (the app's own
    # server-side snooze/etc. parent) shows up verbatim as "Mailspring" in the
    # mailbox list. Category.displayName falls through to `return decoded` for
    # it; add a decoded === 'Mailspring' -> 'Other' case just before the INBOX
    # one so it reads "Other" instead.
    cat="$work/src/flux/models/category.js"
    if grep -q "if (decoded === 'INBOX') {" "$cat"; then
      substituteInPlace "$cat" \
        --replace-fail \
          "if (decoded === 'INBOX') {" \
          "if (decoded === 'Mailspring') { return 'Other'; } if (decoded === 'INBOX') {"
      changed=1
      echo "mailspring: renamed the 'Mailspring' sidebar mailbox to 'Other'"
    else
      echo "mailspring: WARNING category.js displayName line not found -- upstream changed it; leaving it" >&2
    fi

    [ "$changed" = 1 ] && asar pack "$work" "$asarFile"
    rm -rf "$work"
  '';
})
