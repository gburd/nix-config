# Email migration: Fastmail → ProtonMail for greg@burd.me

Moving the `burd.me` custom domain off Fastmail and onto Proton's hosted mail,
making Proton (via the local bridge) the primary neomutt account, and removing
Fastmail entirely.

`greg@burd.me` is a **custom domain**: mail is delivered wherever the domain's
`MX` records point. "Migrating to Proton" therefore means (a) adding `burd.me`
to Proton as a custom domain, (b) moving existing mail Fastmail → Proton, and
(c) flipping `MX` to Proton. The nix-config changes only rewire the *client*;
the migration itself is DNS + IMAP data movement.

## What the Nix side already does (landed)

- `neomutt/accounts/protonmail.muttrc` — primary account; `from = greg@burd.me`
  (sops `email/proton/from`), IMAP/SMTP via the bridge at `127.0.0.1:1143/1025`,
  and the `Hackers` sidebar mailbox re-homed to the Proton folder.
- `neomuttrc` — Proton is the default (sourced at top); `,h` jumps to the
  Proton `Work/Postgres/Hackers List` folder. Fastmail stays on F4 **during**
  migration, then is removed (Phase 2).
- `email/proton/from` sops key added to floki + meh secrets (= `greg@burd.me`).
- `protonmail-bridge.nix` now imported on floki, meh, **and arnold**.

## Migration steps (do these in order)

### 1. Add burd.me to Proton, keep Fastmail delivering

1. Proton → Settings → Domain names → add `burd.me`.
2. Add the verification `TXT`, then the `DKIM` `CNAME`s Proton gives you.
   **Do not touch `MX` yet** — Fastmail keeps receiving during the transfer.
3. Add `greg@burd.me` as an address on the Proton account.
4. On each bridge host, log the bridge into Proton once (floki/meh have a
   keyring; arnold does not — see §5).

### 2. Bulk-transfer mail with imapsync (rerunnable)

`imapsync` is in nixpkgs. Run it on floki (which has the running bridge as the
destination). Put the Fastmail app password and the bridge password in files
(mode 600) and pass them with `--passfile`, never on the command line.

```sh
nix shell nixpkgs#imapsync -c imapsync \
  --host1 imap.fastmail.com --port1 993 --ssl1 \
  --user1 greg@burd.me --passfile1 /run/user/$UID/fm.pass \
  --host2 127.0.0.1 --port2 1143 --nosslcheck \
  --user2 "$(cat ~/.config/sops-nix/secrets/email/proton/user)" \
  --passfile2 /run/user/$UID/bridge.pass \
  --no-ssl2 --automap --allowsizemismatch
```

- `--automap` preserves the folder hierarchy — `Work/Postgres/Hackers List`
  transfers as-is, so the `,h` macro and `Hackers` sidebar work post-cutover.
- imapsync is **idempotent and resumable**: rerun it repeatedly during the
  dual-delivery window so new Fastmail mail keeps flowing to Proton. The final
  pass, run right before the MX flip, is what makes the migration *complete*.
- Shred the passfiles when done: `shred -u /run/user/$UID/fm.pass /run/user/$UID/bridge.pass`.

### 3. Verify on Proton before cutover

- Send a test from `greg@burd.me` (Proton), confirm DKIM/SPF pass at the
  receiver (e.g. mail-tester.com).
- Confirm the Hackers folder + counts match Fastmail in neomutt (F1, then `,h`).

### 4. Flip MX to Proton

1. A day ahead, lower the `burd.me` `MX` TTL (e.g. 300s) so cutover is fast.
2. Replace the Fastmail `MX` with Proton's `MX` records; set `SPF` (`include:_spf.protonmail.ch`)
   and the DMARC record Proton recommends.
3. Run one more `imapsync` pass after propagation to sweep any mail that hit
   Fastmail during the DNS change.

### 5. arnold's bridge (no keyring)

arnold (Fedora, no gnome-keyring/secret-service) uses the bridge's file vault.
The systemd `--noninteractive` service can't do the first login; do it once by
hand on arnold, then let the service take over:

```sh
# on arnold, interactive terminal
systemctl --user stop protonmail-bridge
protonmail-bridge --cli
>>> login      # enter Proton creds + 2FA once; stored in the file vault
>>> info       # note the bridge IMAP/SMTP password
>>> exit
systemctl --user start protonmail-bridge
```

Record this in `home-manager/_mixins/users/gburd/hosts/arnold-manual-changes.md`.

### 6. Grace period, then remove Fastmail (Phase 2)

Keep the Fastmail account open ~2–4 weeks; run imapsync a couple more times to
catch stragglers. Then land the teardown commit:

- delete `neomutt/accounts/fastmail.muttrc` + its `neomutt/default.nix`
  deployment + cache dir + the F4 macros in `neomuttrc`;
- remove `email/fastmail/{user,pass}` from floki/meh `sops.secrets` and from
  both `secrets.yaml` files;
- close the Fastmail account only after the domain fully resolves to Proton and
  a week+ of mail has landed there with nothing left on Fastmail.
