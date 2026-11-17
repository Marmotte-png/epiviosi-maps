{
  description = "EPIVÍOSI MAPS — cartes OpenStreetMap hors-ligne (Organic Maps) pour EPIVÍOSI OS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
  };

  outputs =
    { self, nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      # Implémente `epiviosi.maps.enable` (option déclarée par le socle EPIVÍOSI OS).
      nixosModules.default = import ./module.nix;

      packages.${system} = {
        epiviosi-maps-setup = pkgs.callPackage ./pkgs/epiviosi-maps-setup { };
        epiviosi-maps-fetch = pkgs.callPackage ./pkgs/epiviosi-maps-fetch { };
        default = self.packages.${system}.epiviosi-maps-fetch;
      };

      checks.${system} = {
        epiviosi-maps-setup = self.packages.${system}.epiviosi-maps-setup;
        epiviosi-maps-fetch = self.packages.${system}.epiviosi-maps-fetch;
        # Test en VM : montage à chaud, redirection des données, redémarrage.
        vm = import ./tests/maps.nix {
          inherit pkgs;
          module = self.nixosModules.default;
        };
      };
    };
}
