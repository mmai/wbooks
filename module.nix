/* 
  wbooks NixOS module, it can be imported in /etc/nixos/configuration.nix, and the options can be used.
  To use, link this file in /etc/nixos/configuration.nix imports declaration, example:

    imports = [
      /path/to/this/file/module.nix
    ];

  Enable the module option:

    services.wbooks.enable = true;
    networking.firewall.allowedTCPPorts = [ 8080 ];

  And rebuild the configuration:

    $ nixos-rebuild switch

  Documentation: https://nixos.org/nixos/manual/index.html#sec-writing-modules
*/

{ config, pkgs, lib ? pkgs.lib, ... }:

with lib;

let
  cfg = config.services.wbooks;
  # Using the wbooks build file in this directory
  wbooksPackage = (import ./. {});

  wbooksEnvironment = [
    "STATIC_ROOT=${cfg.apiRoot}/static"
  ];
  wbooksEnvFileData = builtins.concatStringsSep "\n" wbooksEnvironment;
  wbooksEnvScriptData = builtins.concatStringsSep " " wbooksEnvironment;
  wbooksEnvFile = pkgs.writeText "wbooks.env" wbooksEnvFileData;
  wbooksEnv = {
    ENV_FILE = "${wbooksEnvFile}";
  };

in
{
  options = {
    services.wbooks = {
      enable = mkEnableOption "wbooks";
      user = mkOption {
        type = types.str;
        default = "wbooks";
        description = "User under which wbooks is ran.";
      };

      group = mkOption {
        type = types.str;
        default = "wbooks";
        description = "Group under which wbooks is ran.";
      };

      apiRoot = mkOption {
        type = types.str;
        default = "/srv/wbooks";
        description = ''
          Base directory of the wbooks service. Will contains a 'static/' subdirectory where files such as API css or icons will be served. Ensure this directory actually exists.
        '';
      };

      apiIp = mkOption {
        type = types.str;
        default = "127.0.0.1";
        description = ''
            wbooks API IP.
        '';
      };

      apiPort = mkOption {
        type = types.port;
        default = 8080;
        description = ''
            wbooks API Port.
        '';
      };

    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ wbooksPackage ];

    users.users = optionalAttrs (cfg.user == "wbooks") (singleton
    { name = "wbooks";
      group = cfg.group;
    });

    users.groups = optionalAttrs (cfg.group == "wbooks") (singleton { name = "wbooks"; });

    systemd.tmpfiles.rules = [
      "d ${cfg.apiRoot} 0755 ${cfg.user} ${cfg.group} - -"
    ];

    systemd.targets.wbooks = {
      description = "wbooks";
      wants = ["wbooks-server.service"];
    }; 

    systemd.services = 
    let serviceConfig = {
      User = "${cfg.user}";
      WorkingDirectory = "${pkgs.wbooks}";
      EnvironmentFile =  "${wbooksEnvFile}";
    };
    in { 
      wbooks-init = {
        description = "wbooks initialization";
        wantedBy = [ "wbooks-server.service" ];
        before   = [ "wbooks-server.service" ];
        environment = wbooksEnv;
        serviceConfig = {
          User = "${cfg.user}";
          Group = "${cfg.group}";
        };
        script = ''
            if ! test -e ${cfg.apiRoot}/static; then
              mkdir -p ${cfg.apiRoot}/static
              ln -s ${wbooksEnvFile} ${cfg.apiRoot}/.env
            fi
        '';
      };

      wbooks-server = { 
        partOf    = [ "wbooks.target" ];
        environment = wbooksEnv;
        after    = [ "network.target" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = { 
          ExecStart = "${wbooksPackage}/bin/wbooks";
          Restart   = "always";
        };
      };
    };
  };

  meta = {
    maintainers = with lib.maintainers; [ mmai ];
  };
}
