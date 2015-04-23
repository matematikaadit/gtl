#!/usr/bin/env bash

PHPSESSID="$1"
CSRF_TOKEN="$2"
CURL_HOPTS="Cookie: PHPSESSID=$PHPSESSID; YII_CSRF_TOKEN=$CSRF_TOKEN"

TOKILEARNING='http://tokilearning.org'
MAIN_PAGE="$TOKILEARNING/training/7/chapter/46"

TMP_TEMPLATE="$(basename "$0").XXX"
TMPDIR="$(mktemp -dt "$TMP_TEMPLATE")"
trap 'rm -rf "$TMPDIR"' EXIT

scrapping() { curl -s "$1" -H "$CURL_HOPTS" | grep "$2"; }
cannonize_url() { cut -d\" -f2 | sed "s|^|$TOKILEARNING|"; }
listing() { scrapping "$1" "$2" | cannonize_url; }
get_title() { scrapping "$@" '<title>' |  sed 's|^ *<title>TOKI Learning Center - ||;s|</title> *$||;s|&amp;|\&|'; }
normalize_title() { sed 'y/ :/_-/;s/&/dan/g' <<< "$@"; }
accepted_submission_url() { scrapping "$@" '<td>Accepted</td>' | head -n1 | grep -o 'href="[^"]*"' | cannonize_url; }
accepted_submission_dl() { sed 's/$/?action=download/' <<< "$@"; }
find_prop() { grep -A1 "<span class=\"name\">$2</span>" "$1" | tail -n1 | sed "$3"; }

download_submission() {
    pname_sed='s/^.*<a [^>]\+>\([^<]\+\)<\/a>.*$/\1/'
    plang_sed='s/^.*<span>\([^<]\+\)<\/span>.*$/\1/'

    while read url; do
        subm="$(accepted_submission_url $url)"
        [ -z "$subm" ] && exit

        subm_file="$(mktemp -p "$TMPDIR" subm.XXX)"
        curl -s "$subm" -H "$CURL_HOPTS" > "$subm_file"

        name="$(find_prop "$subm_file" "Soal" "$pname_sed")"
        lang="$(find_prop "$subm_file" "Bahasa Pemrograman" "$plang_sed")"

        dl=$(accepted_submission_dl $subm);
        fname="$(normalize_title $name).$lang"

        echo "===============> $name ($fname)"
        curl -s "$dl" -H "$CURL_HOPTS" > "$fname"
    done < "$@"
}

MAIN_FILE="$(mktemp -p "$TMPDIR" MAIN.XXX)"
listing "$MAIN_PAGE" 'chapter-link' > "$MAIN_FILE"

while read url; do
    chapter_title="$(get_title $url)"
    echo "==> Processing $chapter_title"

    chapter_file="$(mktemp -p "$TMPDIR" "$(normalize_title $chapter_title).XXX")"
    listing "$url" 'chapter-link' > "$chapter_file"

    while read ch_url; do
        subch_title="$(get_title $ch_url)"
        echo "======> Processing SUBBAB: $subch_title"

        subch_dir="$(normalize_title $subch_title)"
        subch_file="$(mktemp -p "$TMPDIR" "$subch_dir.XXX")"
        echo "=========> Saving to directory: $subch_dir"
        mkdir -p "$subch_dir"
        echo "============> Downloading submission"
        (
            cd "$subch_dir"
            listing "$ch_url" 'problem-link' | sed 's/problem/submission/' > "$subch_file"
            [ -n "$(scrapping "$ch_url" 'class="next"')" ] && listing "$ch_url?page=2" 'problem-link' | sed 's/problem/submission/' >> "$subch_file"
            download_submission "$subch_file"
        )
        [ -z "$(ls "$subch_dir")" ] && rmdir "$subch_dir"
    done < "$chapter_file"

done < "$MAIN_FILE"
