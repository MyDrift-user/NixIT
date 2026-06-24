# Installing & Deploying

> For the full go-live runbook (secrets → install → per-service config), see
> **[../DEPLOY.md](../DEPLOY.md)**. This page is the install/deploy mechanics.

NixIT installs and updates machines declaratively from your workstation — no
interactive on-box installer. Three tools do the work:

- **disko** — disk partitioning declared in `hosts/<host>/disk.nix`
- **nixos-anywhere** — partition + install over SSH, in one command
- **deploy-rs** — push config updates with automatic rollback

## 1. Define the host

1. Most service VMs need **no host dir** — they're one `mkAppServer` line in
   `flake.nix` pointing at a `modules/services/<svc>/` module (the shared
   `hosts/_common/server-host.nix` base supplies disk/user/network). For a custom
   machine, add `hosts/<host>/` (`default.nix`, `disk.nix`, `network.nix`,
   `users.nix`) and use the `mkServer` / `mkDesktop` helpers.
2. Add a `nixosConfigurations.<host>` entry + a `deploy.nodes.<host>` entry.
3. `nix flake check` — confirms it evaluates.

## 2. Install

Boot the target into any Linux with SSH — the NixOS minimal ISO, this repo's
bootstrap ISO (`nix build .#nixosConfigurations.iso.config.system.build.isoImage`),
or nixos-anywhere's built-in kexec image. Then, from your workstation:

```bash
./scripts/install-host.sh <host> root@<target-ip>
```

This **seeds the host's pre-generated SSH key** from
`../mdl-infra/deployments/<host>/` (created by `scripts/gen-secrets.sh`, with its
age pubkey already in `.sops.yaml`) so first boot decrypts. If no pre-generated key
exists it generates a fresh one and prints its age pubkey for you to register.

> ⚠️ The target disk is **wiped**. Test layout changes with
> `nixos-anywhere --vm-test --flake .#<host>` first.

## 3. Update

```bash
nix run github:serokell/deploy-rs -- .#<host>
```

deploy-rs activates the new config and, if the machine stops responding, rolls
back automatically (`magicRollback`) — so a bad config can't lock you out.

## Disk layout (disko)

UEFI + GPT + btrfs subvolumes (`@`, `@home`, `@nix`, `@log`), zstd compression:

| Partition | Size      | Type        | Mount   |
|-----------|-----------|-------------|---------|
| ESP       | 512 MiB   | EFI System  | `/boot` |
| swap      | 8 GiB     | Linux swap  | —       |
| root      | remainder | btrfs       | `/` etc |

Edit `hosts/<host>/disk.nix` to change sizes, device, or add encryption (LUKS),
mdadm, ZFS, etc. — see the [disko examples](https://github.com/nix-community/disko/tree/master/example).

## Secrets bootstrap

Already done for this fleet — keys + values generated, encrypted in `secrets/`,
plaintext source of truth in `../mdl-infra/deployments/`. See
[secrets.md](secrets.md) for editing and for adding a new machine.
