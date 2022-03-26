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

function log()
{
  echo $@ 1>&2
}

function curl_with_auth()
{
  curl -H "Authorization: \`Bearer $token\`" $@
}

function get_latest_torrents()
{
  log "getting torrent list..."

  curl_with_auth -s "https://dl.rpdl.net/api/torrents?page_size=${page_size}&sort=uploaded_DESC" |
    jq '.data.results[] | "\(.torrent_id);\(.title)"' | tr -d '"' | sort -n
}

function already_downloaded()
{
  grep -q $1 $state_file
}

while true
do
  torrents=( $(get_latest_torrents) )

  test ${#torrents[@]} -eq 0 && log "no new torrents"

  for t in ${torrents[@]}
  do
    read torrent_id torrent_title <<< ${t//;/ }

    destination="$download_path/$torrent_title.torrent"

    if already_downloaded $torrent_id || test -s $destination
    then
      continue
    fi

    if test -f $destination && ! test -s $destination
    then
      #file is empty for some reason; remove it so curl doesn't just skip it
      rm $destination
    fi

    echo "echo 1>&2 + getting $torrent_title; curl -s --compressed -H 'Authorization: \`Bearer $token\`' https://dl.rpdl.net/api/torrent/download/$torrent_id -o $download_path/$torrent_title.torrent && echo $torrent_id >> $state_file"
  done | xargs -n 1 -d \\n -P $parallelism sh -c

  log -e "\nsleeping for $wait_time_in_secs secs..."
  sleep $wait_time_in_secs
done

