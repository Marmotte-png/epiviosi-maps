# EPIVÍOSI MAPS

Cartes OpenStreetMap hors-ligne pour [EPIVÍOSI OS](https://github.com/Marmotte-png/epiviosi),
avec [Organic Maps](https://organicmaps.app) : affichage, recherche d'adresses et de lieux,
itinéraires à pied, à vélo et en voiture, sans connexion.

## Fonctionnement

- Les cartes sont trop grosses pour l'ISO : elles vivent dans la **persistance**,
  `~/Persistant/OrganicMaps` (partition ext4 `EPIVIOSI-DATA`, créée par
  `sudo epiviosi-persist-setup`).
- Le lanceur **EPIVÍOSI MAPS** y redirige tout le dossier de données d'Organic Maps
  (`~/.local/share/OMaps`) : cartes, favoris et traces sont conservés malgré la session
  amnésique. Sans persistance, Organic Maps n'affiche que la carte du monde simplifiée.
- Pas de partition dédiée : sur une clé, la table MBR de l'ISO n'offre que 2 partitions
  libres, prises par le wiki (`EPIV-WIKI`) et la persistance.
- Les cartes doivent correspondre exactement à la version de l'application :
  `epiviosi-maps-fetch` lit la liste des régions (`countries.txt`) de l'Organic Maps installé et
  télécharge la bonne version.
- La licence et l'écran de bienvenue d'Organic Maps sont validés d'avance.

## Télécharger des cartes

Dans EPIVÍOSI, avec la persistance active et une connexion :

```sh
epiviosi-maps-fetch                     # cartes de la France (≈ 4,9 Go, outre-mer compris)
```

`epiviosi-maps-fetch` vérifie l'espace libre, reprend un téléchargement interrompu (relancer la
même commande) et vérifie la somme SHA-1 de chaque fichier. Autres usages :

```sh
epiviosi-maps-fetch --list                      # tous les pays, avec leur taille
epiviosi-maps-fetch --list France               # les régions françaises
epiviosi-maps-fetch Belgium Switzerland         # ajouter des pays
epiviosi-maps-fetch "France_Ile-de-France"      # une seule région
epiviosi-maps-fetch --dry-run Germany           # taille, sans télécharger
epiviosi-maps-fetch --dest DOSSIER France       # ailleurs que dans la persistance
```

| Zone | Taille approx. (données 2026-05) |
| --- | --- |
| France (94 fichiers) | ≈ 4,9 Go |
| Belgique / Suisse | ≈ 0,6 Go chacune |
| Allemagne | ≈ 4,5 Go |
| Europe (hors Russie) | ≈ 30 Go |
| Monde | ≈ 89 Go |

## Utilisation dans un flake

Le module implémente l'option `epiviosi.maps.enable`, déclarée par le socle EPIVÍOSI OS :

```nix
inputs.epiviosi-maps = {
  url = "github:Marmotte-png/epiviosi-maps";
  inputs.nixpkgs.follows = "nixpkgs";
};
# …
modules = [ epiviosi-maps.nixosModules.default { epiviosi.maps.enable = true; } ];
```

## Tests

```sh
nix flake check                      # paquets + test en VM (nécessite KVM dans le bac à sable Nix)
# Sans KVM dans le bac à sable, lancer le test sous son propre utilisateur :
$(nix build --no-link --print-out-paths .#checks.x86_64-linux.vm.driver)/bin/nixos-test-driver
```

Le test vérifie le dossier de données ordinaire sans persistance, la redirection vers
`~/Persistant/OrganicMaps` (contenu existant conservé), la licence et l'écran de bienvenue
préremplis, l'outil de téléchargement hors-ligne (`--list`, `--dry-run`), puis le retour à un
dossier ordinaire quand la persistance disparaît.

## Structure

| Chemin | Rôle |
| --- | --- |
| `module.nix` | Module NixOS : lanceur EPIVÍOSI MAPS (redirection vers la persistance) |
| `pkgs/epiviosi-maps-fetch/` | Outil `epiviosi-maps-fetch` (téléchargement vérifié des cartes) |
| `tests/maps.nix` | Test NixOS en VM |

## Licence

[Hippocratic License 2.1](LICENSE). Données cartographiques © contributeurs
[OpenStreetMap](https://www.openstreetmap.org/copyright) (ODbL).
