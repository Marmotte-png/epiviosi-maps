# EPIVÍOSI MAPS : cartes OpenStreetMap hors-ligne avec Organic Maps.
#
# Les cartes (France ≈ 5 Go) sont trop grosses pour l'ISO : elles vivent sur
# une partition exFAT étiquetée EPIV-MAPS (`sudo epiviosi-maps-setup`, ou
# formatée depuis Windows, macOS, Linux), montée sur /maps, et se téléchargent
# avec `epiviosi-maps-fetch`. Quand la partition est présente, tout le dossier
# de données d'Organic Maps y est redirigé : cartes, favoris et traces sont
# conservés sur la clé malgré la session amnésique.
#
# Ce module implémente l'option `epiviosi.maps.enable`, déclarée par le socle
# EPIVÍOSI OS (modules/epiviosi-modules.nix).
{ config, lib, pkgs, ... }:
let
  cfg = config.epiviosi.maps;
  label = "EPIV-MAPS";
  deviceUnit = "dev-disk-by\\x2dlabel-EPIV\\x2dMAPS.device";
  mountUnit = "maps.mount";

  epiviosi-maps-setup = pkgs.callPackage ./pkgs/epiviosi-maps-setup { };
  epiviosi-maps-fetch = pkgs.callPackage ./pkgs/epiviosi-maps-fetch { };

  # Avant chaque lancement : ~/.local/share/OMaps pointe vers /maps/organicmaps
  # si la partition est là, sinon c'est un dossier ordinaire (carte du monde
  # simplifiée seulement).
  launcher = pkgs.writeShellScriptBin "epiviosi-maps" ''
    PATH=${lib.makeBinPath [ pkgs.coreutils pkgs.util-linux pkgs.gnugrep ]}:$PATH

    # Session amnésique : sans cela, la licence et l'écran de bienvenue
    # reviendraient à chaque démarrage.
    conf="''${XDG_CONFIG_HOME:-$HOME/.config}/OMaps/settings.ini"
    mkdir -p "$(dirname "$conf")"
    touch "$conf"
    for kv in EulaAccepted=true ShowWelcome=false; do
      grep -q "^''${kv%%=*}=" "$conf" || echo "$kv" >> "$conf"
    done

    data="''${XDG_DATA_HOME:-$HOME/.local/share}/OMaps"
    if mountpoint -q /maps && [ -w /maps ]; then
      mkdir -p /maps/organicmaps
      if [ ! -L "$data" ]; then
        if [ -d "$data" ]; then
          cp -rn "$data"/. /maps/organicmaps/ 2>/dev/null || true
          rm -rf "$data"
        fi
        mkdir -p "$(dirname "$data")"
        ln -s /maps/organicmaps "$data"
      fi
    else
      [ -L "$data" ] && rm -f "$data"
      mkdir -p "$data"
    fi
    exec ${pkgs.organicmaps}/bin/OMaps "$@"
  '';

  desktopItem = pkgs.makeDesktopItem {
    name = "epiviosi-maps";
    desktopName = "EPIVÍOSI MAPS";
    genericName = "Cartes hors-ligne";
    comment = "Cartes OpenStreetMap, recherche et itinéraires hors-ligne (Organic Maps)";
    exec = "epiviosi-maps";
    icon = "organicmaps";
    categories = [
      "Education"
      "Geography"
    ];
    keywords = [
      "carte"
      "map"
      "gps"
      "itinéraire"
      "openstreetmap"
      "organic"
    ];
  };

  # Organic Maps sans son propre lanceur (remplacé par EPIVÍOSI MAPS) ni son
  # binaire dans le PATH : toujours lancé via la redirection ci-dessus.
  organicmapsData = pkgs.runCommand "organicmaps-epiviosi" { } ''
    mkdir -p $out/share
    ln -s ${pkgs.organicmaps}/share/icons $out/share/icons
  '';
in
{
  config = lib.mkIf cfg.enable {
    boot.supportedFilesystems.exfat = true;

    systemd.mounts = [
      {
        what = "/dev/disk/by-label/${label}";
        where = "/maps";
        type = "exfat";
        options = "gid=${toString config.ids.gids.users},fmask=0113,dmask=0002,noatime";
        wantedBy = [ deviceUnit ];
      }
    ];

    # Partition déjà présente dans l'initrd : voir epiviosi-persist-boot.
    systemd.services.epiviosi-maps-boot = {
      description = "Montage de la partition EPIVÍOSI MAPS présente au démarrage";
      wantedBy = [ "multi-user.target" ];
      after = [ "systemd-udev-trigger.service" ];
      serviceConfig.Type = "oneshot";
      script = ''
        if [ -e /dev/disk/by-label/${label} ]; then
          systemctl start --no-block ${mountUnit}
        fi
      '';
    };

    environment.systemPackages = [
      organicmapsData
      launcher
      desktopItem
      epiviosi-maps-setup
      epiviosi-maps-fetch
      pkgs.exfatprogs
    ];
  };
}
