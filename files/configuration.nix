#
# vpsfree nixos config (openvz)
#

{ config, pkgs, ... }:
with pkgs.lib;
{
    imports =
      [
        <nixpkgs/nixos/modules/profiles/minimal.nix>
        <nixpkgs/nixos/modules/virtualisation/container-config.nix>
        <nixpkgs/nixos/modules/installer/cd-dvd/channel.nix>
        ./gen/clone-config.nix # optionally include itself
      ];

    services.openssh.enable = true;
    services.openssh.permitRootLogin = "yes";
    services.openssh.startWhenNeeded = false;

    networking = {
      hostName = "nixos";
    };

    fileSystems = [ ];

    system.build.tarball = import <nixpkgs/nixos/lib/make-system-tarball.nix> {
      inherit (pkgs) stdenv perl xz pathsFromGraph;

      contents = [];
      storeContents = [
        { object = config.system.build.toplevel + "/init";
          symlink = "/sbin/init";
        }
        { object = config.system.build.toplevel;
          symlink = "/run/current-system";
        }
        # this is needed as openvz uses /bin/sh for running scripts before container starts
        { object = config.environment.binsh;
          symlink = "/bin/sh";
        }
      ];
      extraCommands = "mkdir -p etc proc sys dev/shm dev/pts run";
    };

    boot.isContainer = true;
    boot.loader.grub.enable = false;
    boot.postBootCommands =
      ''
        # After booting, register the contents of the Nix store in the Nix database.
        if [ -f /nix-path-registration ]; then
          ${config.nix.package.out}/bin/nix-store --load-db < /nix-path-registration &&
          rm /nix-path-registration
        fi

        # nixos-rebuild also requires a "system" profile
        ${config.nix.package.out}/bin/nix-env -p /nix/var/nix/profiles/system --set /run/current-system
      '';

    # need to remove capabilities added by default by nixos/modules/tasks/network-interfaces.nix
    security.wrappers = {
         ping.source = "${pkgs.iputils.out}/bin/ping";
    };


    i18n = {
       defaultLocale = "en_US.UTF-8";
       # make sure not to list defaultLocale here again
       supportedLocales = ["en_US/ISO-8859-1"];
    };

    environment.systemPackages = [ pkgs.nvi ];

    system.activationScripts.installInitScript = ''
      ln -fs $systemConfig/init /sbin/init
    '';

    systemd.services."getty@".enable = false;
    systemd.services.systemd-sysctl.enable = false;

    systemd.services.systemd-journald.serviceConfig.SystemCallFilter = "";
    systemd.services.systemd-journald.serviceConfig.MemoryDenyWriteExecute = false;
    systemd.services.systemd-logind.serviceConfig.SystemCallFilter = "";
    systemd.services.systemd-logind.serviceConfig.MemoryDenyWriteExecute = false;

    nix.package = (import (pkgs.fetchFromGitHub {
        owner = "NixOS";
        repo = "nixpkgs";
        rev = "300fa462b31ad2106d37fcdb4b504ec60dfd62aa";
        sha256 = "1cbjmi34ll5xa2nafz0jlsciivj62mq78qr3zl4skgdk6scl328s";
    }) {}).nix;

    nixpkgs.config.packageOverrides = super:
        let systemdGperfCompat = super.systemd.override { gperf = super.gperf_3_0; };
        in {
          systemd = systemdGperfCompat.overrideAttrs ( oldAttrs: rec {
            version = "232";
            name = "systemd-${version}";
            src = pkgs.fetchFromGitHub {
              owner = "nixos";
              repo = "systemd";
              rev = "66e778e851440fde7f20cff0c24d23538144be8d";
              sha256 = "1valz8v2q4cj0ipz2b6mh5p0rjxpy3m88gg9xa2rcc4gcmscndzk";
            };
          });
    };
}
