# Core packages - shared across all machines
{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    git
    btop
    ncdu
    curl
    wget
    nano
  ];

  # Swiss German console keyboard
  console.keyMap = "sg";

  # Flakes + nix-command
  nix.settings.experimental-features = [ "flakes" "nix-command" ];

  # Weekly garbage collection
  nix.gc = {
    automatic = true;
    dates     = "weekly";
    options   = "--delete-older-than 30d";
  };

  # Weekly store optimisation
  nix.optimise = {
    automatic = true;
    dates     = "weekly";
  };
}
