# sops-nix base configuration - secret decryption at activation time
{ ... }: {
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  sops.age.generateKey = true;
  sops.age.keyFile = "/var/lib/sops-nix/key.txt";
}
