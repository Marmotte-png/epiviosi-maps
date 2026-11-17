# EPIVÍOSI MAPS

Cartes OpenStreetMap hors-ligne pour [EPIVÍOSI OS](https://github.com/Marmotte-png/epiviosi),
avec [Organic Maps](https://organicmaps.app) : affichage, recherche d'adresses et de lieux,
itinéraires à pied, à vélo et en voiture, sans connexion.

## Fonctionnement

- Les cartes sont trop grosses pour l'ISO : elles vivent sur une partition **exFAT** étiquetée
  **`EPIV-MAPS`**, montée sur `/maps` dès qu'elle apparaît (au démarrage ou branchée à chaud).
- Le lanceur **EPIVÍOSI MAPS** redirige tout le dossier de données d'Organic Maps
  (`~/.local/share/OMaps`) vers `/maps/organicmaps` : cartes, favoris et traces sont conservés
  sur la clé malgré la session amnésique. Sans la partition, Organic Maps n'affiche que la carte
  du monde simplifiée.
- Les cartes doivent correspondre exactement à la version de l'application :
  `epiviosi-maps-fetch` lit la liste des régions (`countries.txt`) de l'Organic Maps installé et
  télécharge la bonne version.

## Préparer une clé

Dans EPIVÍOSI, sur la clé de démarrage, avec une connexion :

```sh
sudo epiviosi-maps-setup --size 8G      # partition EPIV-MAPS (sans --size : tout l'espace libre)
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
```

| Zone | Taille approx. (données 2026-05) |
| --- | --- |
| France (94 fichiers) | ≈ 4,9 Go |
| Belgique / Suisse | ≈ 0,6 Go chacune |
| Allemagne | ≈ 4,5 Go |
| Europe (hors Russie) | ≈ 30 Go |
| Monde | ≈ 89 Go |

Ordre conseillé sur une clé de 128 Go : `epiviosi-wiki-setup --size 75G`, puis
`epiviosi-maps-setup --size 8G`, puis `epiviosi-persist-setup` dans l'espace restant.

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

Le test monte une partition `EPIV-MAPS` à chaud, vérifie la redirection du dossier de données
(contenu existant conservé), l'outil de téléchargement hors-ligne (`--list`, `--dry-run`), puis
un redémarrage avec la partition présente et le retour à un dossier ordinaire sans partition.

## Structure

| Chemin | Rôle |
| --- | --- |
| `module.nix` | Module NixOS : montage, lanceur EPIVÍOSI MAPS |
| `pkgs/epiviosi-maps-setup/` | Outil `epiviosi-maps-setup` (création de la partition) |
| `pkgs/epiviosi-maps-fetch/` | Outil `epiviosi-maps-fetch` (téléchargement vérifié des cartes) |
| `tests/maps.nix` | Test NixOS en VM |

## Licence

[Hippocratic License 2.1](LICENSE). Données cartographiques © contributeurs
[OpenStreetMap](https://www.openstreetmap.org/copyright) (ODbL).
