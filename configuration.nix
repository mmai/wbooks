{ config, pkgs, ... }:

with pkgs;

let wbooksHost = "wbooks.local";
in
{ 

  imports = [ ./module.nix ];

  networking.extraHosts =
    ''
    127.0.0.1 ${wbooksHost}
    '';

  # See nixos/modules/services/web-apps/funkwhale.nix for all available options
  services.wbooks = {
    enable = true;
    hostname = wbooksHost;
    protocol = "http"; # for tests on vbox
  };

  time.timeZone = "Europe/Paris";
  services.fail2ban.enable = true;
  networking.firewall.allowedTCPPorts = [ 80 443 ];

  # The NixOS release to be compatible with for stateful data such as databases.
  system.stateVersion = "20.03";
}
