#!/bin/bash

if ! command -v zenity &> /dev/null; then
    echo "Zenity n'est pas installé. Installe-le avec : sudo apt install zenity"
    exit 1
fi

DOSSIER_PDF=$(zenity --file-selection --directory --title="Choisis un dossier contenant les fichiers PDF")
if [ -z "$DOSSIER_PDF" ]; then
    zenity --error --text="Aucun dossier sélectionné. Abandon."
    exit 1
fi

DOSSIER_TEXTE="./corpus_txt"
DOSSIER_RESUMES="./resumes"

mkdir -p "$DOSSIER_TEXTE"
mkdir -p "$DOSSIER_RESUMES"

(
echo "Conversion des fichiers PDF en texte avec pdftotext.sh..."

if [ ! -x ./pdftotext.sh ]; then
    echo "Le script pdftotext.sh est introuvable ou non exécutable."
    exit 1
fi

for fichier_pdf in "$DOSSIER_PDF"/*.pdf; do
    nom_fichier=$(basename "$fichier_pdf" .pdf)
    fichier_txt="$DOSSIER_TEXTE/$nom_fichier.txt"

    if [ -f "$fichier_txt" ]; then
        echo "Le fichier $fichier_txt existe déjà, conversion ignorée."
        continue
    fi

    echo "Conversion de $fichier_pdf"
    ./pdftotext.sh "$fichier_pdf" "$DOSSIER_TEXTE"

    if [ $? -ne 0 ]; then
        echo "Erreur lors de la conversion de $fichier_pdf"
        continue
    fi

    echo "Fichier $fichier_pdf converti avec succès."
    tmp_fichier="$fichier_txt.tmp"

    awk '
    BEGIN { count = 0 }
    /^[[:space:]]*$/ {
        if (count > 0) print ""
        empty=1
        next
    }
    {
        if (count < 3) {
            # On force un retour à la ligne après chaque ligne de l’en-tête
            print $0
        } else {
            if (empty) {
                print $0
            } else {
                printf "%s ", $0
            }
        }
        count++
        empty=0
    }
    END { print "" }
    ' "$fichier_txt" > "$tmp_fichier" && mv "$tmp_fichier" "$fichier_txt"
done

echo "Conversion et mise en page terminées pour tous les fichiers."

echo "Génération des fichiers de résumés..."

cd extractInfo/main || exit 1

if [ "$1" == "-x" ]; then
  cargo run --release ../../corpus_txt ../../resume xml
else
  cargo run --release ../../corpus_txt ../../resume txt
fi

) | zenity --progress --title="Traitement des fichiers" --text="Traitement en cours..." --pulsate --auto-close --width=500 --height=100

if [ $? -eq 0 ]; then
    zenity --info --text="Traitement terminé avec succès."
else
    zenity --error --text="Une erreur est survenue pendant le traitement."
fi