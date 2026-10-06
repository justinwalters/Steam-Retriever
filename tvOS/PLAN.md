# Steam Retriever Big Picture (tvOS): plan

Source of truth for requirements: `docs/tvos-handoff.md` on `main` (API contract, UX spec, ground rules). This file is how we get there.

## Shape of the app

```
┌───────────────────────── Apple TV app (GPL-3.0, branch tvos-app) ─────────────────────────┐
│ SteamRetrieverTV/  (our SwiftUI code)                                                     │
│   App/        AppModel: splash → probe → Setup | Home → Launching → Streaming → Home      │
│   API/        RetrieverAPI (ping, pair, games, cover, launch, status), models, errors      │
│   Services/   TokenStore (Keychain), HostDiscovery (Bonjour), PlayHistory (Continue shelf) │
│   Streaming/  StreamLauncher protocol  ← MoonlightStreamLauncher (phase 3) / Preview stub  │
│   UI/         Theme, Splash, Setup, Home (side nav, hero, shelves, search), Launching      │
│                                                                                            │
│ moonlight-ios fork (phase 3): pairing, decode, controller input, StreamFrameViewController │
└───────────────────────────────────────┬────────────────────────────────────────────────────┘
                 HTTP :48080 (token)    │    Moonlight protocol :47984/47989/...
┌───────────────────────────────────────▼────────────────────────────────────────────────────┐
│ Mac mini: Steam Retriever.app (APIServer.swift)        Sunshine ("Desktop" app)            │
└────────────────────────────────────────────────────────────────────────────────────────────┘
```

The UI code never imports Moonlight directly. It talks to a `StreamLauncher` protocol, so the whole browse → launch → poll flow can be built and run in the tvOS simulator against `mock/mock_server.py` before Moonlight is involved.

## Phases

| # | Goal | Done when |
|---|------|-----------|
| **0** | **Skeleton (this commit)** | Standalone `SteamRetrieverTV.xcodeproj` that runs in the tvOS simulator against the mock: splash, probe, Setup (find Mac, pair code), Home with nav/hero/shelves/search, Launching screen polling status. Streaming is a stub that shows "stream would start now". |
| 1 | Real mini | Point at `mini.local`, pair with the Mac app's 6-digit code, real covers and launch. Sunshine-paused banner. Continue shelf. |
| 2 | Moonlight builds | Fork moonlight-ios, tvOS target builds on current Xcode and streams "Desktop" from the mini with the stock UI (proves Sunshine + controller path before we touch it). |
| 3 | One app | Our sources added to the fork's tvOS target; `MoonlightStreamLauncher` drives Moonlight's pairing (`PairManager`, PIN on screen) and `StreamFrameViewController` for the "Desktop" app; storyboard host list replaced by our SwiftUI root. Setup step 3 (Sunshine pairing) and step 4 (test stream) go live. |
| 4 | Polish | In-stream overlay (Menu long-press: Return to library, Stream settings), error screens with Retry / Open Settings at the failing step, focus/scale/glow tuning, app icon + top shelf. |

### Moonlight integration approach (phase 2-3)

moonlight-ios's tvOS target ("Moonlight TV") already has a Swift bridging header, and starting a stream is a `StreamConfiguration` (host, appID, cert, codec flags) handed to `StreamFrameViewController`; today `MainFrameViewController -prepareToStreamApp:` builds it. Plan:

1. Fork lives at `github.com/justinwalters/moonlight-ios`, branch `steam-retriever`, added here as a submodule at `tvOS/moonlight-ios`.
2. Fork diff kept small: (a) extract `prepareToStreamApp:` into a reusable `SRStreamStarter` (ObjC) callable from Swift, (b) add our `SteamRetrieverTV/` folder to the tvOS target by reference, (c) swap the storyboard root for our SwiftUI host. Everything else in the fork stays upstream so rebasing on new Moonlight releases stays easy.
3. The standalone project from phase 0 stays as the fast UI loop (simulator + mock, no streaming).

## Decisions

- **Style:** the UX spec (Big Picture navy: `#171D25` bg, `#1B2838` panels, `#2A475E` accents, `#66C0F4` highlight) wins over the earlier "dark steampunk" note. Sprocket and the brass gear stay as the mascot on splash, setup and the launching screen, so it still feels like Steam Retriever. No Valve logos or art.
- **License:** everything under `tvOS/` is GPL-3.0 (it links Moonlight). `tvos-app` never merges into `main` (MIT).
- **Signing:** none needed for the simulator. Device builds wait for Justin (ground rule: ask before signing/accounts).
- **Minimum tvOS:** 17. Needs Xcode 16+ (project uses folder-synchronized groups, so new files appear without editing the project).
- **Network:** plain HTTP on the LAN: `NSAllowsLocalNetworking`, `NSLocalNetworkUsageDescription`, `NSBonjourServices` = `_steamretriever._tcp`, `_nvstream._tcp`.
- **Timeouts everywhere:** ping 2 s, API calls 8 s, launch poll every 2 s up to 6 min. Every wait shows a Settings button.

## Needs Justin

1. **Fork moonlight-ios** to your GitHub (phase 2). It creates a repo on your account, so it's your call; say the word and I'll set up the submodule and branch.
2. **Running on the real Apple TV** needs your Apple Development team in Xcode → Signing. I won't touch certificates; you pick the team when you're ready.
3. Confirm the style call above (Big Picture navy + Sprocket).

## Running the skeleton

```sh
python3 tvOS/mock/mock_server.py          # on the MacBook, port 48080, token "dev", pair code 123456
open tvOS/SteamRetrieverTV.xcodeproj       # scheme SteamRetrieverTV → any Apple TV simulator → Run
```
In the app's Setup, use address `127.0.0.1` (the simulator shares the Mac's network) and pair code `123456`.
