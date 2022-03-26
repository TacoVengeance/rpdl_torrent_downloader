## rpdl.net torrent file downloader

Bash version of NodeJS version by @cake

### Purpose

This script queries the latest .torrent files from https://dl.rpdl.net and downloads any new ones since the last run.
It runs in a loop and waits 60 seconds between runs. If you need to run it from a crontab, just yank the loop out.

### Requirements

A recent Bash version, [`jq`](https://stedolan.github.io/jq/) and `curl`.

### Usage

Create a file in this directory called `token.txt`, and put your rpdl.net token in the first line, without quotes or spaces or anything else.
Then, run the script with `./download_rpdl_torrent_files.sh`.

