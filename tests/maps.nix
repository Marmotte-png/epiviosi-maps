# Test NixOS du module EPIVÍOSI MAPS : partition EPIV-MAPS branchée à chaud,
# redirection du dossier de données d'Organic Maps, outil de téléchargement
# (sans réseau : --dry-run et --list), redémarrage avec la partition présente.
{ pkgs, module }:
pkgs.testers.runNixOSTest {
  name = "epiviosi-maps";

  nodes.machine =
    { lib, ... }:
    {
      imports = [ module ];
      # Options normalement déclarées par le socle EPIVÍOSI OS.
      options.epiviosi = {
        user = lib.mkOption {
          type = lib.types.str;
          default = "epiviosi";
        };
        maps.enable = lib.mkEnableOption "EPIVÍOSI MAPS";
      };
      config = {
        epiviosi.maps.enable = true;
        virtualisation.emptyDiskImages = [ 256 ];
        virtualisation.memorySize = 2048;
        users.users.epiviosi.isNormalUser = true;
      };
    };

  testScript = ''
    def as_user(cmd):
        return machine.succeed(f"su - epiviosi -c '{cmd}'")

    # Lance Organic Maps sans affichage quelques secondes (crée ses dossiers).
    run_maps = "QT_QPA_PLATFORM=offscreen timeout 15 epiviosi-maps || true"

    machine.wait_for_unit("multi-user.target")

    with subtest("sans partition : dossier de données ordinaire"):
        machine.fail("mountpoint -q /maps")
        as_user(run_maps)
        as_user("test -d ~/.local/share/OMaps && test ! -L ~/.local/share/OMaps")
        as_user("touch ~/.local/share/OMaps/favori-test")

    with subtest("partition branchée à chaud"):
        machine.succeed("mkfs.exfat -L EPIV-MAPS /dev/vdb")
        machine.succeed("udevadm trigger --action=add /dev/vdb && udevadm settle")
        machine.wait_for_unit("maps.mount")
        machine.succeed("findmnt -no FSTYPE /maps | grep -qx exfat")

    with subtest("données redirigées vers /maps, contenu existant conservé"):
        as_user(run_maps)
        target = as_user("readlink ~/.local/share/OMaps").strip()
        assert target == "/maps/organicmaps", target
        machine.succeed("test -f /maps/organicmaps/favori-test")

    with subtest("outil de téléchargement (hors-ligne)"):
        out = as_user("epiviosi-maps-fetch --dry-run")
        assert "France" in out and "Reste à télécharger" in out, out
        out = as_user("epiviosi-maps-fetch --list France")
        assert "France_Corsica" in out, out
        machine.fail("su - epiviosi -c 'epiviosi-maps-fetch --dry-run Atlantide'")

    with subtest("redémarrage avec la partition déjà présente"):
        machine.shutdown()
        machine.start()
        machine.wait_for_unit("maps.mount")
        as_user(run_maps)
        machine.succeed("test -f /maps/organicmaps/favori-test")
        target = as_user("readlink ~/.local/share/OMaps").strip()
        assert target == "/maps/organicmaps", target

    with subtest("partition retirée : retour à un dossier ordinaire"):
        machine.succeed("umount /maps")
        as_user(run_maps)
        as_user("test -d ~/.local/share/OMaps && test ! -L ~/.local/share/OMaps")
  '';
}
