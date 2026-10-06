#!/bin/bash
# Collects Sunshine's state and log tail into sunshine-diag.txt (same folder). Changes nothing.
cd "$(dirname "$0")"
OUT="$PWD/sunshine-diag.txt"
BREW=$(ls /opt/homebrew/bin/brew /usr/local/bin/brew 2>/dev/null | head -1)
{
echo "== $(date)  macOS $(sw_vers -productVersion)"
echo "== processes"; ps -axo pid,pcpu,rss,etime,stat,comm | grep -i '[s]unshine'
echo "== brew services"; "$BREW" services list 2>&1 | grep -i -E 'name|sunshine'
echo "== launchd"; launchctl print "gui/$(id -u)/sh.brew.sunshine" 2>&1 | grep -E 'state|pid|last exit|runs|program' | head -12
echo "== listening ports"; lsof -nP -iTCP -iUDP 2>/dev/null | grep -i '[s]unshine' | head -20
echo "== all sunshine-related processes (full command lines)"; ps -axww -o pid,ppid,etime,command | grep -i '[s]unshine' | cut -c1-200
echo "== launchd jobs mentioning sunshine"; launchctl list 2>/dev/null | grep -i sunshine
echo "== Bonjour: is Sunshine advertising? (4 s)"; (timeout 4 dns-sd -B _nvstream._tcp local. 2>&1 || true) | head -8
echo "== listeners on Sunshine's ports"; lsof -nP -iTCP:47984 -iTCP:47989 -iTCP:47990 -iTCP:48010 -sTCP:LISTEN 2>/dev/null | head
echo "== Switch log (tail)"; tail -15 /Volumes/STEAM/Hub/sunshine-switch.log 2>&1
echo "== web UI probe (5 s timeout)"; curl -k -s -o /dev/null -m 5 -w "HTTP %{http_code} in %{time_total}s\n" https://localhost:47990/ 2>&1
echo "== log files"; ls -l ~/.config/sunshine/*.log /opt/homebrew/var/log/sunshine* /usr/local/var/log/sunshine* 2>&1 | head
for f in ~/.config/sunshine/sunshine.log /opt/homebrew/var/log/sunshine.log; do
  [ -f "$f" ] && { echo "== tail $f"; tail -60 "$f"; }
done
} > "$OUT" 2>&1
echo "Saved $OUT"
read -p "Press Enter to close"
