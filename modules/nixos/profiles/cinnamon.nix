{
  services.xserver = {
    enable = true;
    displayManager.lightdm.enable = true;
    desktopManager.cinnamon.enable = true;
  };

  programs.firefox.enable = true;
  services.printing.enable = true;
}
