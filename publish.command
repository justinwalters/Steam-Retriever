#!/bin/bash
# Creates the public GitHub repo "Steam-Retriever" from this folder and pushes it.
# GitHub repo names cannot contain spaces, so "Steam Retriever" becomes "Steam-Retriever".
cd "$(dirname "$0")" || exit 1
NAME="Steam-Retriever"
DESC="Native macOS launcher for macOS Steam and CrossOver Steam, with a steampunk golden retriever pup."

if ! command -v git >/dev/null 2>&1; then
  echo "git is missing. Run: xcode-select --install   then run this again."
  exit 1
fi

GH="$(command -v gh || true)"
if [ -z "$GH" ]; then
  echo "Fetching GitHub's command line tool (one time)..."
  TMP="$(mktemp -d)"
  if [ "$(uname -m)" = "arm64" ]; then A=arm64; else A=amd64; fi
  VER="$(curl -fsSL https://api.github.com/repos/cli/cli/releases/latest | sed -n 's/.*"tag_name": *"v\([^"]*\)".*/\1/p' | head -1)"
  curl -fsSL -o "$TMP/gh.zip" "https://github.com/cli/cli/releases/download/v${VER}/gh_${VER}_macOS_${A}.zip" || { echo "Download failed."; exit 1; }
  unzip -q "$TMP/gh.zip" -d "$TMP"
  GH="$(ls "$TMP"/gh_*/bin/gh | head -1)"
fi

if ! "$GH" auth status >/dev/null 2>&1; then
  echo "Sign in to GitHub in the browser window that opens (enter the code shown here)."
  "$GH" auth login --hostname github.com --git-protocol https --web || exit 1
fi

LOGIN="$("$GH" api user -q .login)"
[ -d .git ] || git init -q -b main
git add -A
git -c user.name="${LOGIN}" -c user.email="${LOGIN}@users.noreply.github.com" commit -q -m "Steam Retriever: native launcher for macOS Steam and CrossOver Steam

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_011Bdb3Swwup7spxjtgwcmkp" || true

if "$GH" repo view "${LOGIN}/${NAME}" >/dev/null 2>&1; then
  git remote get-url origin >/dev/null 2>&1 || git remote add origin "https://github.com/${LOGIN}/${NAME}.git"
  git push -u origin main
else
  "$GH" repo create "$NAME" --public --description "$DESC" --source . --remote origin --push
fi
echo
echo "Done: https://github.com/${LOGIN}/${NAME}"
