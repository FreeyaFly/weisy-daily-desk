#!/bin/sh
# Weisy launcher (macOS, also works on Linux): start the local server if it is not running, then open the page.
# The server stops by itself a few seconds after the last Weisy window or tab is closed.
cd "$(dirname "$0")" || exit 1
PORT=8780
URL="http://127.0.0.1:$PORT/"

if ! curl -s "${URL}api/ping" | grep -q weisy; then
  PY=$(command -v python3 || command -v python)
  if [ -z "$PY" ]; then
    echo "Python 3 was not found. Install it from https://www.python.org and try again."
    printf "Press Return to close. "; read -r _
    exit 1
  fi
  "$PY" tools/build.py >/dev/null
  nohup "$PY" server.py --port "$PORT" >/dev/null 2>&1 &
  i=0
  until curl -s -o /dev/null "${URL}api/ping"; do
    i=$((i + 1))
    if [ "$i" -gt 20 ]; then
      echo "Weisy did not start."
      "$PY" server.py --check
      echo "If the line above says \"Data folder\", run \"$PY server.py\" in this folder to see the error."
      printf "Press Return to close. "; read -r _
      exit 1
    fi
    sleep 1
  done
fi

if command -v open >/dev/null 2>&1; then
  open "$URL"
elif command -v xdg-open >/dev/null 2>&1; then
  xdg-open "$URL" >/dev/null 2>&1
else
  echo "Open $URL in your browser."
fi
