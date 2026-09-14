{ pkgs, ... }:

{
  programs.zsh.enable = true;
  users.users.boboysdadda.shell = pkgs.zsh;

  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
    defaultNetwork.settings.dns_enabled = true;
  };

  environment.systemPackages = with pkgs; [
    podman-compose
  ];
}
