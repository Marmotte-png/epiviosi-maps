# EPIVÍOSI MAPS : cartes OpenStreetMap hors-ligne avec Organic Maps.
#
# Les cartes (France ≈ 5 Go) sont trop grosses pour l'ISO : elles vivent dans
# la persistance, ~/Persistant/OrganicMaps (partition EPIVIOSI-DATA, créée par
# `sudo epiviosi-persist-setup`), et se téléchargent avec `epiviosi-maps-fetch`.
# Le lanceur y redirige tout le dossier de données d'Organic Maps : cartes,
# favoris et traces sont conservés malgré la session amnésique. Sans
# persistance, Organic Maps n'affiche que la carte du monde simplifiée.
#
# (Pas de partition dédiée : sur la clé, la table MBR de l'ISO n'offre que
# 2 partitions libres, prises par le wiki et la persistance.)
#
# Ce module implémente l'option `epiviosi.maps.enable`, déclarée par le socle
# EPIVÍOSI OS (modules/epiviosi-modules.nix).
{ config, lib, pkgs, ... }:
let
  cfg = config.epiviosi.maps;
  epiviosi-maps-fetch = pkgs.callPackage ./pkgs/epiviosi-maps-fetch { };

  # Avant chaque lancement : ~/.local/share/OMaps pointe vers
  # ~/Persistant/OrganicMaps si la persistance est là, sinon c'est un dossier
  # ordinaire (carte du monde simplifiée seulement).
  launcher = pkgs.writeShellScriptBin "epiviosi-maps" ''
    PATH=${lib.makeBinPath [ pkgs.coreutils pkgs.gnugrep ]}:$PATH

    # Session amnésique : sans cela, la licence et l'écran de bienvenue
    # reviendraient à chaque démarrage.
    conf="''${XDG_CONFIG_HOME:-$HOME/.config}/OMaps/settings.ini"
    mkdir -p "$(dirname "$conf")"
    touch "$conf"
    for kv in EulaAccepted=true ShowWelcome=false; do
      grep -q "^''${kv%%=*}=" "$conf" || echo "$kv" >> "$conf"
    done

    data="''${XDG_DATA_HOME:-$HOME/.local/share}/OMaps"
    cartes="$HOME/Persistant/OrganicMaps"
    if [ -d "$HOME/Persistant" ] && [ -w "$HOME/Persistant" ]; then
      mkdir -p "$cartes"
      if [ ! -L "$data" ]; then
        if [ -d "$data" ]; then
          cp -rn "$data"/. "$cartes"/ 2>/dev/null || true
          rm -rf "$data"
        fi
        mkdir -p "$(dirname "$data")"
        ln -s "$cartes" "$data"
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
    environment.systemPackages = [
      organicmapsData
      launcher
      desktopItem
      epiviosi-maps-fetch
    ];
  };
}
