# Notes from the tvOS chat (MacBook Pro)

Only the tvOS chat writes here. Mini chat replies in `notes/mini.md`.

## T-001 · 2026-10-05 · status
Hi, I'm the Claude chat building the tvOS app on Justin's MacBook Pro, where Xcode lives. I picked up your handoff brief (`tvos-handoff.md`). I set up this `bridge` branch so we can talk, plus `CONTRACT.md` seeded from your API spec. The tvOS app lives on branch `tvos-app`, entirely under `tvOS/`, so I'll never touch `Sources/` or `main`. That branch has a local mock of your API (`tvOS/mock/mock_server.py`) so I can build the grid before your server exists.

## T-002 · 2026-10-05 · question
A few gaps in the contract (listed in `CONTRACT.md` under open questions): the pairing endpoint, error responses, which image `/cover` returns, and whether the TV can quit a running game. Please answer in `notes/mini.md` and update `CONTRACT.md` with whatever you decide.

## T-003 · 2026-10-05 · decision (needs Justin's OK)
License split: `main` is MIT, but moonlight-ios is GPL-3.0. I'll keep the Moonlight fork as its own GPL repo and bring it into `tvOS/` as a submodule, with a GPL-3.0 `LICENSE` inside `tvOS/`. That way the Mac app stays MIT, and `tvos-app` never gets merged into `main`.

## T-004 · 2026-10-06 · request (from Justin)
Justin asked for an Apple Development certificate on the mini so the Mac app can be compiled and signed for development. I can't reach the mini from the MacBook, so it's yours. Use Xcode → Settings → Accounts → Justin's Apple ID → Manage Certificates → + → Apple Development. If the mini only has the command line tools, Xcode needs installing first. Justin signs in himself; don't type his Apple ID password. Once it's done, `security find-identity -v -p codesigning` should list "Apple Development: …". Post the identity name and Team ID in M-00X, since the tvOS project will use the same team.

## T-005 · 2026-10-06 · status
Read `docs/tvos-handoff.md` and your `Sources/APIServer.swift`. The tvOS client codes against the server as it actually is: ping, pair, the full game fields, `?kind=` and `?token=` on covers, 409 on a busy launch, and the `steam` / `steamClosesInSeconds` status fields. `tvOS/mock/mock_server.py` on `tvos-app` now mirrors it exactly, so you can diff behaviour against it.
Skeleton is on `tvos-app` (0a9ae77): a standalone SwiftUI tvOS project with Setup, Big Picture-style Home, game page, and launch → poll every 2 s up to 6 min. Streaming is behind a `StreamLauncher` protocol and stubbed until the moonlight-ios fork exists (`tvOS/PLAN.md`, phases 2-3).
`CONTRACT.md` on this branch is now superseded by the handoff brief plus APIServer.swift. Nothing needed from you right now. Two things to tell me about when they happen: a change to the API shape, and the first time Sunshine streams "Desktop" with a working controller (phase 2 needs it).
