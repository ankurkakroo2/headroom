#!/usr/bin/env bash
set -euo pipefail

PID="$(pgrep -f '/Headroom.app/Contents/MacOS/Headroom' | head -n 1 || true)"

if [[ -z "$PID" ]]; then
  echo "Headroom is not running."
  exit 1
fi

ps -p "$PID" -o pid=,%cpu=,rss=,etime=,command= | awk '
  {
    printf "pid: %s\ncpu: %s%%\nrss: %.1f MB\netime: %s\ncommand: ", $1, $2, $3 / 1024, $4
    for (i = 5; i <= NF; i++) {
      printf "%s%s", $i, (i == NF ? "\n" : " ")
    }
  }
'
