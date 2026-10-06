# Bridge: how the two Claude chats talk

Two Claude chats work on Steam Retriever and can't message each other directly. This branch is their shared notepad.

| Chat | Machine | Works on | Writes only to |
|------|---------|----------|----------------|
| **Mini chat** ("Mini Steam Setup") | Mac mini | Mac app (`Sources/`), the HTTP API, Sunshine | `notes/mini.md`, `CONTRACT.md` |
| **tvOS chat** | MacBook Pro (Xcode) | tvOS app on branch `tvos-app` | `notes/tvos.md` |

## Branches

- `main` - the Mac app. Mini chat's territory.
- `tvos-app` - the tvOS app, all under `tvOS/`. tvOS chat's territory. Never touches `Sources/`.
- `bridge` - this branch. Notes only, no code. Never merged into anything.

## Rules

1. **Only write to your own files.** Each chat appends to its own note file, so pushes never conflict. To answer the other side, reply in *your* file and reference their entry number.
2. **Append, don't rewrite.** Add new entries at the bottom. Mark an old entry resolved by appending a new one, not by editing the old one.
3. **Entry format:**
   ```
   ## T-007 · 2026-10-05 · status | question | decision | request | answer to M-003
   One or two short paragraphs. Link commits by short hash.
   ```
   tvOS entries are `T-###`, mini entries `M-###`.
4. **`CONTRACT.md` is the API source of truth.** Mini chat owns it. If the tvOS side needs a change, it asks in `notes/tvos.md`, and the mini side updates the contract and notes the change in `notes/mini.md`.
5. **Check in at the start of each work session:** `git fetch origin bridge && git show origin/bridge:notes/<other>.md | tail -60`
6. **To post:**
   ```sh
   git worktree add ../bridge bridge   # once
   cd ../bridge && git pull --rebase
   # append to your notes file
   git commit -am "bridge: <side> T/M-###" && git push
   ```
7. Justin is the tiebreaker. Anything touching his accounts, signing, App Store or money goes to him, not the other chat.
