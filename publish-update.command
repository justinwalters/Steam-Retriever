#!/bin/bash
# Commits the current folder to the existing Steam-Retriever repo and pushes.
cd "$(dirname "$0")" || exit 1
GH="$(command -v gh || ls /opt/homebrew/bin/gh /usr/local/bin/gh 2>/dev/null | head -1)"
if [ -z "$GH" ]; then
  TMP="$(mktemp -d)"; if [ "$(uname -m)" = "arm64" ]; then A=arm64; else A=amd64; fi
  VER="$(curl -fsSL https://api.github.com/repos/cli/cli/releases/latest | sed -n 's/.*"tag_name": *"v\([^"]*\)".*/\1/p' | head -1)"
  curl -fsSL -o "$TMP/gh.zip" "https://github.com/cli/cli/releases/download/v${VER}/gh_${VER}_macOS_${A}.zip" || exit 1
  unzip -q "$TMP/gh.zip" -d "$TMP"; GH="$(ls "$TMP"/gh_*/bin/gh | head -1)"
fi
if ! "$GH" auth status >/dev/null 2>&1; then
  echo "Sign in to GitHub in the browser window that opens."
  "$GH" auth login --hostname github.com --git-protocol https --web || exit 1
fi
"$GH" auth setup-git >/dev/null 2>&1
LOGIN="$("$GH" api user -q .login)"
git add -A
git -c user.name="${LOGIN}" -c user.email="${LOGIN}@users.noreply.github.com" commit -q -m "Add Apple TV API, auto full screen, Sunshine Switch, stable signing

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_011Bdb3Swwup7spxjtgwcmkp" || echo "(nothing new to commit)"
git push -u origin main
echo; echo "Done: https://github.com/${LOGIN}/Steam-Retriever"
read -p "Press Enter to close"
