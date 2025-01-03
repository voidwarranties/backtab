{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) types mkOption mkIf mkMerge;

  backtabConfigFile = pkgs.writeText "config.yml" ''
    http:
      listen: '${cfg.httpListenAddress}'
      port: ${builtins.toString cfg.httpListenPort}
    event_mode: false
    datadir: /var/lib/backtab
    slowdown: ${builtins.toString cfg.slowdown}
  '';

  cfg = config.services.backtab;
in {
  options = {
    services.backtab = {
      enable = lib.mkEnableOption "backtab";

      httpListenAddress = mkOption {
        type = types.str;
        default = "127.0.0.1";
        description = "Address on which the Backtab service should listen.";
      };

      httpListenPort = mkOption {
        type = types.int;
        default = 4903;
        description = "Port on which the Backtab service should listen.";
      };

      slowdown = mkOption {
        type = types.int;
        default = 0;
        description = "Undocumented option (adding delay to transactions?).";
      };

      repositoryUrl = mkOption {
        type = types.str;
        description = "URL of the git repository containing the ledger for Backtab.";
      };

      gitUserName = mkOption {
        type = types.str;
        default = "Backtab server";
        description = "Username used for commit messages.";
      };

      gitUserEmail = mkOption {
        type = types.str;
        default = "backtab@example.com";
        description = "Email used for commit messages.";
      };

      authorizedKeys = mkOption {
        type = types.listOf types.str;
        default = [];
        description = ''
          Authorized public SSH keys of users that can log into the Backtab user account on the server that's running
          the backtab application. This access can be used to generate the necessary public/private ssh keypair
          (`ssh-keygen`) that the allow the backtab to push commits to the ledger repository.
          This access can also be used to resolve problems / conflicts with the stateful ledger data stored in
          /var/lib/backtab.
        '';
      };
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      users.groups.backtab = {};
      users.users.backtab = {
        isNormalUser = true;
        group = "backtab";
        openssh.authorizedKeys.keys = cfg.authorizedKeys;
      };

      programs.ssh.knownHosts = {
        "github.com".publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
      };

      systemd.services.backtab-init-datadir = {
        description = "Backtab data directory initialization";
        after = ["network-online.target"];
        wants = ["network-online.target"];
        serviceConfig = {
          User = "backtab";
          Group = "backtab";
          Type = "oneshot";
        };
        path = [pkgs.openssh];
        script = ''
          if ! [[ -d /var/lib/backtab/.git ]]; then
            ${pkgs.git}/bin/git clone ${cfg.repositoryUrl} /var/lib/backtab
            ${pkgs.git}/bin/git config --global user.name "${cfg.gitUserName}"
            ${pkgs.git}/bin/git config --global user.email "${cfg.gitUserEmail}"
          fi
        '';
      };

      systemd.services.backtab = {
        description = "Backtab bar tab backend server application";
        requires = ["backtab-init-datadir.service"];
        wantedBy = ["multi-user.target"];
        after = [
          "network-online.target"
          "backtab-init-datadir.service"
        ];
        wants = ["network-online.target"];
        serviceConfig = {
          User = "backtab";
          Group = "backtab";
          ExecStart = "${lib.getExe pkgs.backtab} -c ${backtabConfigFile}";
        };
        path = with pkgs; [git openssh];
      };

      systemd.tmpfiles.rules = [
        "d /var/lib/backtab 0750 backtab backtab -"
      ];
    }
  ]);
}
