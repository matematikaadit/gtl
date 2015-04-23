#!/usr/bin/env bash
set -e

PHPSESSID="$1"
CSRF_TOKEN="$2"
TOKILEARNING='http://tokilearning.org'
CURL_HOPTS="Cookie: PHPSESSID=$PHPSESSID; YII_CSRF_TOKEN=$CSRF_TOKEN" 
MAIN_PAGE="$TOKILEARNING/training/7/chapter/46"
MAIN_FILE="main.txt"

scrapping() {
  curl -s "$1" -H "$CURL_HOPTS" | grep "$2"
}

cannonize_url() {
  cut -d\" -f2 | sed "s|^|$TOKILEARNING|"
}

listing() {
  scrapping "$1" "$2" | cannonize_url
}

get_title() {
  scrapping "$1" '<title>' |  sed 's|^ *<title>TOKI Learning Center - ||;s|</title> *$||;s|&amp;|\&|'
}

normalize_title() {
  echo "$1" | sed 'y/ :/_-/;s/&/dan/g'
}

accepted_submission_url() {
  scrapping "$1" '<td>Accepted</td>' | head -n1 | grep -o 'href="[^"]*"' | cannonize_url 
}

accepted_submission_dl() {
  echo "$1" | sed 's/$/?action=download/'
}

find_prop() {
  grep -A1 "<span class=\"name\">$2</span>" "$1" | sed '2!d' | sed "$3"
}

download_submission() {
  pname_sed='s/^.*<a [^>]\+>\([^<]\+\)<\/a>.*$/\1/'
  plang_sed='s/^.*<span>\([^<]\+\)<\/span>.*$/\1/'
  for url in $(cat "$1"); do
    subm=$(accepted_submission_url "$url");
    curl -s "$subm" -H "$CURL_HOPTS" > __subm.txt
    name="$(find_prop __subm.txt "Soal" "$pname_sed")"
    lang="$(find_prop __subm.txt "Bahasa Pemrograman" "$plang_sed")"
    dl=$(accepted_submission_dl "$subm");
    fname="$(normalize_title "$name").$lang"
    echo "===============> Downloading solution of problem: $name"
    echo "===============> Saving to: $fname"
    curl -s "$dl" -H "$CURL_HOPTS" > "$fname"
    rm __subm.txt
  done
}

listing "$MAIN_PAGE" 'chapter-link' > "$MAIN_FILE"

for url in $(cat "$MAIN_FILE"); do
  chapter_title="$(get_title "$url")"
  echo "==> Processing $chapter_title"

  chapter_file="$(normalize_title "$chapter_title").txt"
  listing "$url" 'chapter-link' > "$chapter_file"

  for ch_url in $(cat "$chapter_file"); do
    subch_title="$(get_title $ch_url)"
    echo "======> Processing SUBBAB: $subch_title"

    subch_dir="$(normalize_title "$subch_title")"
    subch_file="$subch_dir.txt"
    echo "=========> Saving to directory: $subch_dir"
    mkdir -p "$subch_dir"
    echo "============> Processing submission"
    (
      cd "$subch_dir"
      listing "$ch_url" 'problem-link' | sed 's/problem/submission/' > "$subch_file"
      [ -n "$(scrapping "$ch_url" 'class="next"')" ] && listing "$ch_url?page=2" 'problem-link' | sed 's/problem/submission/' >> "$subch_file" 
      download_submission "$subch_file"
      rm "$subch_file"
    )
  done

  rm "$chapter_file"
done

rm "$MAIN_FILE"
