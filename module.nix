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
  frontPackage = (import ./front-default.nix {});
  wbooksEnvironment = [
    "STATIC_ROOT=${cfg.apiRoot}/public"
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
          Base directory of the wbooks service. Will contains a 'public/' subdirectory where files such as API css or icons will be served. Ensure this directory actually exists.
        '';
      };

      protocol = mkOption {
        type = types.enum [ "http" "https" ];
        default = "https";
        description = ''
            Web server protocol.
        '';
      };

      hostname = mkOption {
        type = types.str;
        default = "wbooks.local";
        description = ''
            wbooks hostname.
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
        default = 3030;
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

    services.nginx = {
      enable = true;
      appendHttpConfig = ''
          upstream wbooks-api {
          server ${cfg.apiIp}:${toString cfg.apiPort};
          }
      '';
      virtualHosts = 
      let proxyConfig = ''
          # global proxy conf
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
          proxy_set_header X-Forwarded-Host $host:$server_port;
          proxy_set_header X-Forwarded-Port $server_port;
          proxy_redirect off;

          # websocket support
          proxy_http_version 1.1;
          proxy_set_header Upgrade $http_upgrade;
          proxy_set_header Connection $connection_upgrade;
      '';
      withSSL = cfg.protocol == "https";
      in {
        "${cfg.hostname}" = {
        enableACME = withSSL;
        forceSSL = withSSL;
        root = "${cfg.apiRoot}/";
        # gzip config is nixos nginx recommendedGzipSettings with gzip_types from funkwhle doc (https://docs.funkwhle.audio/changelog.html#id5)
        extraConfig = ''
            add_header Content-Security-Policy "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self' data:; object-src 'none'; media-src 'self' data:";
            add_header Referrer-Policy "strict-origin-when-cross-origin";

            gzip on;
            gzip_disable "msie6";
            gzip_proxied any;
            gzip_comp_level 5;
            gzip_types
            application/javascript
            application/vnd.geo+json
            application/vnd.ms-fontobject
            application/x-font-ttf
            application/x-web-app-manifest+json
            font/opentype
            image/bmp
            image/svg+xml
            image/x-icon
            text/cache-manifest
            text/css
            text/plain
            text/vcard
            text/vnd.rim.location.xloc
            text/vtt
            text/x-component
            text/x-cross-domain-policy;
            gzip_vary on;
        '';
        locations = {
          "/" = { 
            extraConfig = proxyConfig;
            proxyPass = "http://wbooks-api/";
          };
          # "/public/" = {
          #   alias = "${cfg.apiRoot}/public/";
          #   extraConfig = ''
          #   add_header Content-Security-Policy "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self' data:; object-src 'none'; media-src 'self' data:";
          #   add_header Referrer-Policy "strict-origin-when-cross-origin";
          #   expires 30d;
          #   add_header Pragma public;
          #   add_header Cache-Control "public, must-revalidate, proxy-revalidate";
          #   '';
          # };
        };
      };
    };
    };

    systemd.targets.wbooks = {
      description = "wbooks";
      wants = ["wbooks-server.service"];
    }; 

    systemd.services = { 
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
            if ! test -e ${cfg.apiRoot}/public; then
              mkdir -p ${cfg.apiRoot}
              ln -s ${wbooksEnvFile} ${cfg.apiRoot}/.env
              ln -s ${frontPackage} ${cfg.apiRoot}/public
            fi
        '';
      };

      wbooks-server = { 
        partOf    = [ "wbooks.target" ];
        environment = wbooksEnv;
        after    = [ "network.target" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = { 
          User = "${cfg.user}";
          Group = "${cfg.group}";
          WorkingDirectory = "${cfg.apiRoot}";
          EnvironmentFile =  "${wbooksEnvFile}";
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
