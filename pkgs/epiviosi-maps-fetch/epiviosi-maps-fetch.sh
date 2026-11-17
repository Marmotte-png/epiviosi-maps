# epiviosi-maps-fetch — télécharge les cartes Organic Maps d'un pays ou d'une
# région, dans la version exacte attendue par l'Organic Maps d'EPIVÍOSI, avec
# reprise des téléchargements interrompus et vérification SHA-1.
#
# Usage : epiviosi-maps-fetch [--dest DOSSIER] [--dry-run] [RÉGION...]
#         epiviosi-maps-fetch --list [RÉGION]
#   RÉGION    : identifiant Organic Maps, ex. France, France_Corsica, Belgium,
#               Germany. Sans RÉGION : la sélection EPIVÍOSI (France).
#   --list    : liste les pays, ou les sous-régions d'une RÉGION, avec leur taille.
#   --dest    : dossier de données d'Organic Maps (défaut : ~/Persistant/OrganicMaps,
#               dans la partition de persistance EPIVIOSI-DATA).
#   --dry-run : affiche les fichiers et tailles, sans rien télécharger.
#
# OM_COUNTRIES (fourni par le paquet) : countries.txt de l'Organic Maps installé.

DEFAULT=(France)
MIRRORS=(https://cdn.organicmaps.app/ https://cdn-us1.organicmaps.app/)

die() { echo "Erreur : $*" >&2; exit 1; }
usage() { echo "Usage : epiviosi-maps-fetch [--dest DOSSIER] [--dry-run] [RÉGION...] | --list [RÉGION]   (défaut : ${DEFAULT[*]})"; }
human() { numfmt --to=si --suffix=o "$1"; }
sha1_b64() { sha1sum "$1" | cut -c1-40 | tr a-f A-F | basenc --base16 -d | base64; }

[ -r "$OM_COUNTRIES" ] || die "countries.txt d'Organic Maps introuvable ($OM_COUNTRIES)."
version="$(jq -r .v "$OM_COUNTRIES")"

dest="$HOME/Persistant/OrganicMaps" dry=0 list=0 regions=()
while [ $# -gt 0 ]; do
  case "$1" in
    --dest) [ $# -ge 2 ] || die "--dest attend un dossier."; dest="$2"; shift ;;
    --dest=*) dest="${1#--dest=}" ;;
    --dry-run) dry=1 ;;
    --list) list=1 ;;
    -h|--help) usage; exit 0 ;;
    -*) die "option inconnue : $1" ;;
    *) regions+=("$1") ;;
  esac
  shift
done

# Fichiers (id, taille, sha1 en base64, id encodé pour l'URL) d'une région :
# toutes ses feuilles. Certains id contiennent des espaces.
leaves() {
  jq -r --arg r "$1" '
    [.. | objects | select(.id? == $r)] | first // empty
    | [.. | objects | select(has("s") and has("sha1_base64"))] | .[]
    | "\(.id)\t\(.s)\t\(.sha1_base64)\t\(.id | @uri)"' "$OM_COUNTRIES"
}

if [ "$list" = 1 ]; then
  parent="${regions[0]:-}"
  jq -r --arg r "$parent" '
    def size: if has("g") then ([.g[] | size] | add) else (.s // 0) end;
    (if $r == "" then . else ([.. | objects | select(.id? == $r)] | first) end) as $n
    | if $n == null then error("région inconnue") else ($n.g // [])[] | "\(.id)\t\(size)" end
  ' "$OM_COUNTRIES" 2>/dev/null | while IFS=$'\t' read -r id s; do
    printf '  %-45s %8s\n' "$id" "$(human "$s")"
  done
  exit 0
fi

[ ${#regions[@]} -gt 0 ] || regions=("${DEFAULT[@]}")
if [ "$dest" = "$HOME/Persistant/OrganicMaps" ] && [ ! -d "$HOME/Persistant" ]; then
  die "pas de persistance (~/Persistant) : lancez « sudo epiviosi-persist-setup », redémarrez, puis relancez. Sinon : --dest DOSSIER."
fi
[ "$dry" = 1 ] || mkdir -p "$dest" || die "impossible de créer $dest."
target="$dest/$version"

files=""
for r in "${regions[@]}"; do
  l="$(leaves "$r")"
  [ -n "$l" ] || die "région inconnue : $r (voir epiviosi-maps-fetch --list)."
  files+="$l"$'\n'
done
files="$(sort -u <<<"$files" | sed '/^$/d')"

count=0 total=0 todo=0
while IFS=$'\t' read -r id s _; do
  count=$((count + 1)); total=$((total + s))
  if [ -f "$target/$id.mwm" ] && [ "$(stat -c %s "$target/$id.mwm")" = "$s" ]; then continue; fi
  have=0; [ -f "$target/$id.mwm.part" ] && have="$(stat -c %s "$target/$id.mwm.part")"
  todo=$((todo + s - have))
done <<<"$files"

echo "Organic Maps, données $version : $count fichiers, $(human "$total") (${regions[*]})."
if [ "$dry" = 1 ]; then
  echo "Reste à télécharger : $(human "$todo")."
  exit 0
fi
mkdir -p "$target" || die "pas le droit d'écrire dans $dest."
avail="$(df --output=avail -B1 "$target" | tail -n1)"
echo "Reste à télécharger : $(human "$todo") ; libre dans $dest : $(human "$avail")."
[ "$todo" -le "$avail" ] || die "espace insuffisant dans $dest."

n=0
while IFS=$'\t' read -r id s sha uri; do
  n=$((n + 1))
  out="$target/$id.mwm"
  if [ -f "$out" ] && [ "$(stat -c %s "$out")" = "$s" ]; then continue; fi
  echo "[$n/$count] $id ($(human "$s"))"
  ok=0
  for m in "${MIRRORS[@]}"; do
    # Extension .part : Organic Maps ignore le fichier tant qu'il est incomplet.
    if curl -fL --progress-bar -C - --retry 10 --retry-all-errors --retry-delay 5 \
         -o "$out.part" "${m}maps/$version/$uri.mwm" </dev/null; then
      ok=1; break
    fi
    echo "  miroir $m indisponible, essai suivant…"
  done
  [ "$ok" = 1 ] || die "téléchargement de $id impossible ; relancez la même commande pour reprendre."
  if [ "$(sha1_b64 "$out.part")" != "$sha" ]; then
    rm -f "$out.part"
    die "$id est corrompu (SHA-1 différent) ; fichier supprimé, relancez la commande."
  fi
  mv "$out.part" "$out"
done <<<"$files"

echo "Terminé : $count fichiers dans $target."
echo "Ouvrez « EPIVÍOSI MAPS » dans le menu."
