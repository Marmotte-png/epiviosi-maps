# Test NixOS du module EPIVÍOSI MAPS : sans persistance, dossier de données
# ordinaire ; avec persistance (~/Persistant), données redirigées vers
# ~/Persistant/OrganicMaps (contenu existant conservé) ; licence et écran de
# bienvenue préremplis ; outil de téléchargement hors-ligne (--list,
# --dry-run) ; retour à un dossier ordinaire si la persistance disparaît.
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

    with subtest("sans persistance : dossier de données ordinaire"):
        as_user(run_maps)
        as_user("test -d ~/.local/share/OMaps && test ! -L ~/.local/share/OMaps")
        as_user("touch ~/.local/share/OMaps/favori-test")
        rc, out = machine.execute("su - epiviosi -c 'epiviosi-maps-fetch --dry-run 2>&1'")
        assert rc != 0 and "pas de persistance" in out, out

    with subtest("licence et bienvenue préremplies, sans doublon"):
        as_user(run_maps)
        conf = as_user("cat ~/.config/OMaps/settings.ini")
        assert conf.count("EulaAccepted=true") == 1, conf
        assert conf.count("ShowWelcome=false") == 1, conf

    with subtest("persistance : données redirigées, contenu conservé"):
        as_user("mkdir -p ~/Persistant")
        as_user(run_maps)
        target = as_user("readlink ~/.local/share/OMaps").strip()
        assert target == "/home/epiviosi/Persistant/OrganicMaps", target
        as_user("test -f ~/Persistant/OrganicMaps/favori-test")

    with subtest("outil de téléchargement (hors-ligne)"):
        out = as_user("epiviosi-maps-fetch --dry-run")
        assert "France" in out and "Reste à télécharger" in out, out
        out = as_user("epiviosi-maps-fetch --list France")
        assert "France_Corsica" in out, out
        machine.fail("su - epiviosi -c 'epiviosi-maps-fetch --dry-run Atlantide'")

    with subtest("persistance absente : retour à un dossier ordinaire"):
        as_user("mv ~/Persistant ~/Persistant.bak")
        as_user(run_maps)
        as_user("test -d ~/.local/share/OMaps && test ! -L ~/.local/share/OMaps")
  '';
}
