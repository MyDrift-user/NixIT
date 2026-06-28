# Developer workstation tooling — Rust, Python, C#/.NET, Docker, editors.
# System-wide (no home-manager) so it's "just dev stuff" in PATH for any user.
{ pkgs, inputs, ... }:
let
  # VS Code Insiders — packaged directly from Microsoft's official tarball.
  # NOT via `pkgs.vscode.override { isInsiders = true; }`: nixpkgs ships only the
  # stable hash (so isInsiders alone hash-mismatches) and its builder keys the
  # ripgrep path off the pinned `vscodeVersion`, so overriding src to a newer
  # insider always breaks. A self-contained autoPatchelf derivation is independent
  # of that coupling. PIN A SPECIFIC BUILD, never `/latest/` (it drifts daily).
  # To bump: query the update API, take `version` (commit) + `sha256hash`:
  #   curl -s https://update.code.visualstudio.com/api/update/linux-x64/insider/latest
  #   nix hash convert --hash-algo sha256 --to sri <sha256hash>
  vscode-insiders = pkgs.stdenv.mkDerivation {
    pname = "vscode-insiders";
    version = "1.127.0-insider";
    src = pkgs.fetchurl {
      # name gives the store file a .tar.gz extension so unpackPhase untars it —
      # the URL basename ("insider") has none, which breaks unpacking.
      name = "vscode-insiders.tar.gz";
      url = "https://update.code.visualstudio.com/commit:628f6de50e89b20c7688c66ac2923cce2862c1b0/linux-x64/insider";
      hash = "sha256-UHpKF4VLEn/YOH/f+loY/GQeyrv2trbKhiSVth5M/to=";
    };
    nativeBuildInputs = with pkgs; [ autoPatchelfHook makeWrapper wrapGAppsHook3 ];
    # Reuse nixpkgs' vscode runtime closure (exact libs the stable build needs).
    buildInputs = (pkgs.vscode.buildInputs or [ ]) ++ (with pkgs; [ stdenv.cc.cc.lib libglvnd ]);
    dontConfigure = true;
    dontBuild = true;
    dontWrapGApps = true; # wrapped manually below
    installPhase = ''
      runHook preInstall
      mkdir -p "$out/lib/code-insiders" "$out/bin"
      cp -r ./* "$out/lib/code-insiders/"
      makeWrapper "$out/lib/code-insiders/bin/code-insiders" "$out/bin/code-insiders" \
        "''${gappsWrapperArgs[@]}" \
        --prefix LD_LIBRARY_PATH : "${pkgs.lib.makeLibraryPath [ pkgs.libglvnd ]}"
      runHook postInstall
    '';
    # VS Code dlopen's GL via libglvnd (same as nixpkgs' generic.nix postFixup).
    postFixup = ''
      patchelf --add-needed libGLESv2.so.2 --add-needed libGL.so.1 --add-needed libEGL.so.1 \
        "$out/lib/code-insiders/code-insiders" || true
    '';
  };
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
    # mdl-deploy — the working fleet key (deploy-rs + admin). The old NStVTxix key
    # was lost, which locked every desktop/dev box out; never reintroduce it.
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO/pHI10e6RYA3gOw8ptXqvdDyJzkE5eL9ZsCMRVUhv+ mdl-deploy"
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
