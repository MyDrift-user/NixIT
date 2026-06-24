# Developer workstation tooling — Rust, Python, C#/.NET, Docker, editors.
# System-wide (no home-manager) so it's "just dev stuff" in PATH for any user.
{ pkgs, inputs, ... }:
let
  # VS Code Insiders — built from Microsoft's official "latest insider" tarball
  # (there is no maintained nixpkgs/flake for Insiders). To bump it, re-prefetch:
  #   nix store prefetch-file --name vscode-insiders.tar.gz \
  #     https://update.code.visualstudio.com/latest/linux-x64/insider
  # and paste the printed hash below.
  vscode-insiders = (pkgs.vscode.override { isInsiders = true; }).overrideAttrs (_: {
    version = "latest";
    src = pkgs.fetchurl {
      url = "https://update.code.visualstudio.com/latest/linux-x64/insider";
      hash = "sha256-gSlE2ucMqtDR7S3L5FbOaiP3amXc5moyS63PPHsIvdA=";
    };
  });
in {
  # ── Local Docker for dev ────────────────────────────────────────────────
  virtualisation.docker.enable = true;
  users.users.kuze.extraGroups = [ "docker" ];

  # ── SSH (key-only) so deploy-rs can manage this VM too ──────────────────
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
    settings.PermitRootLogin = "prohibit-password";
  };
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINStVTxixre56N5GRSBCIAQTQYQMbFPfrLsCe2l0rUHe"
  ];

  # ── Git identity (system-wide) ──────────────────────────────────────────
  environment.etc."gitconfig".text = ''
    [user]
        name = mydrift-user
        email = contact@mydrift.dev
    [init]
        defaultBranch = main
    [pull]
        rebase = true
    [push]
        autoSetupRemote = true
  '';

  environment.variables.EDITOR = "nvim";

  # ── Tooling ─────────────────────────────────────────────────────────────
  environment.systemPackages = [
    vscode-insiders                                    # `code-insiders`
    inputs.helium.packages.${pkgs.system}.default      # Helium browser
  ] ++ (with pkgs; [
    neovim git gh lazygit
    gcc gnumake pkg-config
    rustc cargo rust-analyzer clippy rustfmt           # Rust
    python3 python3Packages.pip uv ruff pyright        # Python
    dotnet-sdk_9                                        # C# / .NET
    docker-compose lazydocker                           # Docker tooling
    ripgrep fd jq fastfetch
  ]);
}
