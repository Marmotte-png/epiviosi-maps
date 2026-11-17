{
  writeShellApplication,
  organicmaps,
  curl,
  jq,
  coreutils,
  gnused,
}:
writeShellApplication {
  name = "epiviosi-maps-fetch";
  runtimeInputs = [
    curl
    jq
    coreutils
    gnused
  ];
  # Les cartes doivent correspondre exactement à la version des données de
  # l'Organic Maps installé : on lit son countries.txt.
  runtimeEnv.OM_COUNTRIES = "${organicmaps}/share/organicmaps/data/countries.txt";
  text = builtins.readFile ./epiviosi-maps-fetch.sh;
}
