# Developer workstation tooling — Rust, Python, C#/.NET, Docker, editors.
# System-wide (no home-manager) so it's "just dev stuff" in PATH for any user.
{ pkgs, inputs, ... }:
let
  # VS Code Insiders — built from Microsoft's official tarball (no maintained
  # nixpkgs/flake for Insiders). PIN A SPECIFIC BUILD, never `/latest/`: that URL
  # serves a new binary daily so a fixed hash drifts and the build breaks. The
  # `commit:<sha>` URL is content-stable. To bump, query the update API:
  #   curl -s https://update.code.visualstudio.com/api/update/linux-x64/insider/latest
  # take `version` (commit) for the URL and `sha256hash`, then:
  #   nix hash convert --hash-algo sha256 --to sri <sha256hash>
  vscode-insiders = (pkgs.vscode.override { isInsiders = true; }).overrideAttrs (_: {
    version = "1.127.0-insider";
    src = pkgs.fetchurl {
      url = "https://update.code.visualstudio.com/commit:628f6de50e89b20c7688c66ac2923cce2862c1b0/linux-x64/insider";
      hash = "sha256-UHpKF4VLEn/YOH/f+loY/GQeyrv2trbKhiSVth5M/to=";
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
