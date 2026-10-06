# Steam Retriever: tvOS branch (`tvos-app`)

You're the **tvOS session**, running on Justin's MacBook Pro, which has Xcode. You build the Apple TV app "Steam Retriever Big Picture". A separate Claude session on the Mac mini owns the Mac app (`main`, `Sources/`).

## Read first
- `docs/tvos-handoff.md`: requirements, API contract and UX spec (decided with Justin).
- `tvOS/PLAN.md`: phases and architecture. `tvOS/README.md`: how to run it, and the layout.
- `Sources/APIServer.swift`: the real API. The client and `tvOS/mock/mock_server.py` match it exactly.

## Ground rules (Justin's)
- Small, reviewable commits on `tvos-app`. Work only under `tvOS/` (plus this file). Never touch `Sources/` and never merge into `main`. `main` is MIT and everything in `tvOS/` is GPL-3.0 because of Moonlight.
- **Ask Justin before anything that touches his accounts, the App Store or signing certificates.** That includes creating the moonlight-ios fork on GitHub and picking a development team.
- Personal use only. Remote access away from home, multiple Macs and an App Store release are out of scope.

## Where things stand (2026-10-06)
- Phase 0 skeleton is committed: `tvOS/SteamRetrieverTV.xcodeproj` (tvOS 17, Swift 5 mode, folder-synchronized group), with a SwiftUI app covering splash → probe → Setup (4 steps) → Home (side nav, hero, shelves, search, game page) → Launching (polls every 2 s, gives up at 6 min) → stubbed stream.
- **It has never been compiled.** It was written in a cloud session without Xcode and only syntax-checked. First job: build it and fix the errors.
- Streaming goes through the `StreamLauncher` protocol (`tvOS/SteamRetrieverTV/Streaming/`). `PreviewStreamLauncher` is the stand-in until Moonlight is in.

## Next steps
1. Build for the simulator and fix the compile errors:
   `xcodebuild -project tvOS/SteamRetrieverTV.xcodeproj -scheme SteamRetrieverTV -destination 'generic/platform=tvOS Simulator' build`
2. Run `python3 tvOS/mock/mock_server.py` and run the app in an Apple TV simulator. In Setup, use address `127.0.0.1` and code `123456`. Walk through the flows, including the `/mock/...` edge-case switches listed in the README.
3. Phase 1: point the app at the real mini (`mini.local:48080`, pair with the code from the Mac app's gear menu > Pair Apple TV...).
4. Phase 2, **after Justin OKs the fork**: fork moonlight-ios, add it as a submodule at `tvOS/moonlight-ios`, and get its tvOS target building and streaming Sunshine's "Desktop" app. Phase 3: `MoonlightStreamLauncher`, using `StreamConfiguration` and `StreamFrameViewController`. Moonlight's existing setup lives in `MainFrameViewController -prepareToStreamApp:`.

## Open decisions for Justin
- Style: navy Big Picture palette with Sprocket and brass accents (chosen), versus the earlier "dark steampunk" note.
- Fork moonlight-ios to his GitHub (phase 2).
- Signing team for device builds.

## Talking to the mini session
The `bridge` branch is a shared notepad (see `BRIDGE.md` there). Append `T-###` entries to `notes/tvos.md`, and read theirs in `notes/mini.md`:
`git fetch origin && git show origin/bridge:notes/mini.md | tail -60`
Latest from us: T-005 (skeleton status). The mini side hasn't posted yet.
