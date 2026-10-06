#!/bin/bash
# Smoke-tests the Steam Retriever API on this Mac. In Steam Retriever choose gear > "Pair Apple TV..." first,
# then enter the 6-digit code shown in the header when asked. Results: api-test.txt (same folder). Starts no game.
cd "$(dirname "$0")"
OUT="$PWD/api-test.txt"
B="http://localhost:48080"
{
echo "== ping"; curl -s -m 5 "$B/api/ping"; echo
echo "== games without a token (expect 401)"; curl -s -m 5 -o /dev/null -w "HTTP %{http_code}\n" "$B/api/games"
} | tee "$OUT"
read -p "Pairing code from Steam Retriever (6 digits): " CODE
{
echo "== pair"
RESP=$(curl -s -m 5 -X POST "$B/api/pair" -d "{\"code\":\"$CODE\",\"name\":\"api-test\"}")
echo "$RESP" | sed -E 's/"token":"[0-9a-f]{6}[0-9a-f]+"/"token":"(received)"/'
TOKEN=$(echo "$RESP" | sed -nE 's/.*"token":"([0-9a-f]+)".*/\1/p')
if [ -z "$TOKEN" ]; then echo "pairing failed"; else
  echo "== games (first 600 chars)"; curl -s -m 10 -H "X-Retriever-Token: $TOKEN" "$B/api/games" | head -c 600; echo
  echo "== game count"; curl -s -m 10 -H "X-Retriever-Token: $TOKEN" "$B/api/games" | grep -o '"appid"' | wc -l
  echo "== status"; curl -s -m 10 -H "X-Retriever-Token: $TOKEN" "$B/api/status"; echo
  ID=$(curl -s -m 10 -H "X-Retriever-Token: $TOKEN" "$B/api/games" | sed -nE 's/.*"id":"([^"]+)".*/\1/p' | head -1)
  echo "== cover for $ID"; curl -s -m 30 -H "X-Retriever-Token: $TOKEN" -o /tmp/api-cover.jpg -w "HTTP %{http_code}, %{size_download} bytes, %{content_type}\n" "$B/api/games/$ID/cover"
  echo "== bonjour"; (timeout 4 dns-sd -B _steamretriever._tcp 2>&1 || true) | head -6
fi
} | tee -a "$OUT"
echo; echo "Saved $OUT"; read -p "Press Enter to close"
