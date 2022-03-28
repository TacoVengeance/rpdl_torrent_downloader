#!/usr/bin/env bash

#requires curl and jq

#----- config

#write your token into this file in plain text
token_file='token.txt'

wait_time_in_secs=60
download_path='./files'
state_file='already_downloaded_files.txt'
parallelism=6
page_size=5000

#----- end config

test -s $token_file || { echo "ERROR: token file does not exist or is empty: $token_file"; exit 1; }

token=$(head -1 $token_file) || exit 1
mkdir -p $download_path
mkdir -p $(dirname $state_file)
test -f $state_file || > $state_file

function log() {
  echo $@ 1>&2
}

function require() {
  type $1 &>/dev/null || {
    log "ERROR: $1 not present in PATH"
    exit 1
  }
}

require curl
require jq

function curl_with_auth() {
  curl -H "Authorization: \`Bearer $token\`" $@
}

function get_latest_torrents() {
  log "getting torrent list..."

  curl_with_auth -s "https://dl.rpdl.net/api/torrents?page_size=${page_size}&sort=uploaded_DESC" |
    jq '.data.results[] | "\(.torrent_id);\(.title)"' | tr -d '"' | sort -n
}

function already_downloaded() {
  grep -q $1 $state_file
}

function is_empty() {
  test -f $1 && ! test -s $1
}

while true
do
  torrents=( $(get_latest_torrents) )

  test ${#torrents[@]} -eq 0 && log "no new torrents"

  for t in ${torrents[@]}
  do
    read torrent_id torrent_title <<< ${t//;/ }

    destination="$download_path/$torrent_title.torrent"

    if already_downloaded $torrent_id && ! is_empty $destination
    then
      continue
    fi

    #if file is empty for some reason, remove it so curl doesn't just skip it
    is_empty $destination && rm $destination

    echo -n "echo 1>&2 + getting $torrent_title; "
    echo -n "curl -s --compressed -H 'Authorization: \`Bearer $token\`' https://dl.rpdl.net/api/torrent/download/$torrent_id -o $download_path/$torrent_title.torrent "
    echo    "&& echo $torrent_id >> $state_file"
  done | xargs -n 1 -d \\n -P $parallelism sh -c

  log -e "\nsleeping for $wait_time_in_secs secs..."
  sleep $wait_time_in_secs
done

