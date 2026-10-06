#!/bin/bash
# Lists the code-signing certificates this Mac can see. Changes nothing. Output: sign-diag.txt (same folder).
cd "$(dirname "$0")"
OUT="$PWD/sign-diag.txt"
{
echo "== valid code-signing identities"; security find-identity -v -p codesigning 2>&1
echo; echo "== all code-signing identities, valid or not"; security find-identity -p codesigning 2>&1
echo; echo "== keychains searched"; security list-keychains 2>&1
echo; echo "== certificates whose name mentions Apple Development, Distribution or Developer ID"
for n in "Apple Development" "Apple Distribution" "Developer ID Application" "Mac Developer" "iPhone Developer"; do
  security find-certificate -a -c "$n" 2>/dev/null | grep -E '"labl"' | sed 's/^ *//'
done
echo; echo "== Apple WWDR intermediate present?"; security find-certificate -a -c "Apple Worldwide Developer Relations" 2>/dev/null | grep -c labl
} > "$OUT" 2>&1
echo "Saved $OUT"; read -p "Press Enter to close"
