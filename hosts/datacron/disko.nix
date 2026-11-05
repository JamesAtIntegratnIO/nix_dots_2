# The VM's only disk, named the same way as pitdroid's: by its stable
# /dev/disk/by-id path, never /dev/sda. The id is the Proxmox scsi0 slot, so
# it matches this VM's disk once the VM exists and nothing on another machine.
# OVMF boots it, hence the ESP. The Postgres data directory lives on this
# disk (a zvol on local-zfs), never on NFS.
{
  disko.devices.disk.main = {
    type = "disk";
    device = "/dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_drive-scsi0";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          size = "512M";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ];
          };
        };
        root = {
          size = "100%";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/";
          };
        };
      };
    };
  };
}
