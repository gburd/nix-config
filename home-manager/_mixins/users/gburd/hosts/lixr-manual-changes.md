# lixr — host-level changes outside nix-config

lixr is a SpacemiT K3 Pico ITX at 192.168.1.179 running Bianbu 4.0.6. nix-config
manages only its home-manager layer, so everything below was done by hand and
has to be redone if the board is reinstalled.

## Identity

- OS hostname changed `milkv` -> `lixr` with `sudo hostnamectl set-hostname lixr`.
- SSH from floki must pin the key. floki's agent can hold dozens of keys and
  sshd disconnects after about six failed offers:
  `ssh -o IdentitiesOnly=yes -o IdentityAgent=none -i ~/.ssh/id_ed25519 gburd@192.168.1.179`

## Nix

- Installed with the official script: `sh <(curl -L https://nixos.org/nix/install) --daemon --yes`.
  It supports riscv64 (`nix-2.35.3-riscv64-linux.tar.xz`).
- Appended to `/etc/nix/nix.conf`:
  ```
  experimental-features = nix-command flakes
  max-jobs = 8
  cores = 0
  log-lines = 50
  ```
- **No binary cache.** cache.nixos.org has no riscv64-linux coverage, so every
  build is from source.

## Bootstrap gcc workaround (required, or no Nix build works)

`/etc/sysctl.d/99-nix-riscv64-bootstrap.conf`:

```
vm.mmap_min_addr = 61440
```

Without it, nixpkgs' bootstrap `gcc`, `g++`, `cpp`, `collect2` and
`lto-wrapper` die with SIGSEGV before `main`, and every build fails at its
first derivation.

**Cause, proven with controls:**

1. Those five drivers are non-PIE (ELF `EXEC`).
2. `pkgs/stdenv/linux/bootstrap-tools/glibc/unpack-bootstrap-tools.sh:45` runs
   `patchelf --set-interpreter --set-rpath` on them. patchelf 0.15.2 prepends a
   header `LOAD` segment one page below the riscv64 text base, at vaddr
   `0xf000` instead of `0x10000`.
3. Bianbu's procps ships `/usr/lib/sysctl.d/55-zeropage.conf`, which raises
   `vm.mmap_min_addr` from the kernel default 4096 to 65536 (`0x10000`).
4. `0xf000 < 0x10000`, so the loader cannot map the segment.

Running the binary through its own interpreter shows the real error, which the
SIGSEGV hides:
`failed to map segment from shared object`.

Controls: lowering the limit makes the bootstrap gcc work, and restoring it
breaks it again. The host's `/usr/bin/gcc` works throughout. Building a
`-no-pie` binary with the host toolchain (first LOAD `0x10000`, runs) and then
applying the same patchelf call moves it to `0xf000`, and it then segfaults.

61440 (`0xf000`) is the narrowest value that works. It keeps 60 KiB of the
zero-page guard instead of dropping to the 4 KiB kernel default. The `99-`
prefix sorts after `55-zeropage.conf`, so this value wins.

Upstream: NixOS/patchelf#622 and NixOS/nixpkgs#460825, both open. Neither
names `mmap_min_addr`. **Remove this file** once nixpkgs ships riscv64
bootstrap tools whose lowest `LOAD` is >= `0x10000`, or PIE drivers.

## Tailscale

- Installed by hand from `tailscale_1.104.1_riscv64.tgz`:
  `tailscale` -> `/usr/local/bin`, `tailscaled` -> `/usr/local/sbin`, unit and
  defaults from the tarball's `systemd/`.
- The shipped unit hardcodes `/usr/sbin/tailscaled`. It was rewritten with
  `sed -i 's|/usr/sbin/tailscaled|/usr/local/sbin/tailscaled|g'`.
- `systemctl enable --now tailscaled`: running, **not enrolled**. It joins the
  Headscale network once that is deployed. See `~/ws/fly-apps/headscale`.
