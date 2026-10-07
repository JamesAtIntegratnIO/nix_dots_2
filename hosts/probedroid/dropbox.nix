# A drop box for Mom: send files to the Pi with Taildrop (`tailscale file cp
# <file> probedroid:` or the share sheet), and she opens them from the
# "Dropbox" SMB share on her computer (\\probedroid\Dropbox).
#
# Taildrop requires the sender and the Pi to belong to the same Tailscale user,
# so this stops working if the Pi is ever moved to a tag.
#
# Windows refuses guest SMB shares by default, so she signs in as `mom`. Set the
# password on the Pi (it stays out of the repo): `smbpasswd -a mom`.
{ pkgs, ... }:

let
  dir = "/srv/dropbox";
in
{
  users.groups.mom = { };
  users.users.mom = {
    isSystemUser = true;
    group = "mom";
    description = "Samba login for Mom";
  };

  systemd.tmpfiles.rules = [ "d ${dir} 0775 mom mom -" ];

  # Linux Taildrop holds received files in tailscaled's inbox until something
  # fetches them. --wait blocks until at least one file arrives; hand each batch
  # to mom so she can open, rename and delete it over SMB.
  systemd.services.taildrop-receive = {
    description = "Move Taildrop files into ${dir}";
    wantedBy = [ "multi-user.target" ];
    after = [ "tailscaled.service" ];
    requires = [ "tailscaled.service" ];
    path = [
      pkgs.coreutils
      pkgs.tailscale
    ];
    script = ''
      while true; do
        tailscale file get --wait --conflict=rename ${dir}
        chown -R mom:mom ${dir}
        chmod -R u+rw,g+rw ${dir}
      done
    '';
    serviceConfig.Restart = "always";
  };

  services.samba = {
    enable = true;
    # SMB on her LAN; the tailnet is already trusted in network.nix.
    openFirewall = true;
    settings = {
      global = {
        "server string" = "probedroid";
        "map to guest" = "never";
        "server min protocol" = "SMB2_10";
      };
      Dropbox = {
        path = dir;
        "valid users" = "mom";
        "read only" = "no";
        "force user" = "mom";
        "force group" = "mom";
        "create mask" = "0664";
        "directory mask" = "0775";
      };
    };
  };

  # Show up under Network in Windows Explorer...
  services.samba-wsdd = {
    enable = true;
    openFirewall = true;
  };

  # ...and in Finder's sidebar. nixpkgs' Samba is built without mDNS, so
  # advertise the share through avahi directly.
  services.avahi = {
    publish = {
      enable = true;
      userServices = true;
    };
    extraServiceFiles.smb = ''
      <?xml version="1.0" standalone="no"?>
      <!DOCTYPE service-group SYSTEM "avahi-service.dtd">
      <service-group>
        <name replace-wildcards="yes">%h</name>
        <service>
          <type>_smb._tcp</type>
          <port>445</port>
        </service>
        <service>
          <type>_device-info._tcp</type>
          <port>0</port>
          <txt-record>model=RackMac</txt-record>
        </service>
      </service-group>
    '';
  };
}
