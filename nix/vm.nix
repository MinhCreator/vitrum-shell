# A small NixOS with vitrum on, for the flake's checks and for a look in a
# virtual machine:
#
#   nixos-rebuild build-vm --flake .#vm && ./result/bin/run-vitrum-vm
#
# Log in as vitrum (password: vitrum). Not a configuration to install.
{ lib, modulesPath, ... }:
{
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];

  programs.vitrum.enable = true;

  networking.hostName = "vitrum";
  users.users.vitrum = {
    isNormalUser = true;
    initialPassword = "vitrum";
    extraGroups = [
      "wheel"
      "networkmanager"
      "video"
    ];
  };

  # Enough of a machine for the configuration to evaluate; build-vm replaces
  # the disk and the boot loader with its own.
  boot.loader.grub.device = lib.mkDefault "nodev";
  fileSystems."/" = lib.mkDefault {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  virtualisation.vmVariant.virtualisation = {
    memorySize = 4096;
    cores = 4;
    # niri needs a GPU with GLES: virtio's, through the host's.
    qemu.options = [
      "-device virtio-vga-gl"
      "-display gtk,gl=on"
    ];
  };

  system.stateVersion = lib.trivial.release;
}
