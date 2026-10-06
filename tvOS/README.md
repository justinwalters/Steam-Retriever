# Steam Retriever Big Picture (Apple TV)

A tvOS app that opens straight into a Big Picture-style grid of the games on the Mac mini, starts the chosen one through Steam Retriever's API, then streams the mini's screen with Moonlight from Sunshine. One app, no hopping to Steam Link.

- Requirements and UX spec: `docs/tvos-handoff.md` (on `main`)
- How we get there: [`PLAN.md`](PLAN.md)
- Lives on branch **`tvos-app`**, only under `tvOS/`. Never merged into `main`.

## Run it (simulator, no Mac mini needed)

```sh
python3 tvOS/mock/mock_server.py            # fake Steam Retriever on :48080, pair code 123456
open tvOS/SteamRetrieverTV.xcodeproj         # Xcode 16+; scheme SteamRetrieverTV, any Apple TV simulator, Run
```

First launch opens **Setup**. Type `127.0.0.1` as the address (the simulator shares the Mac's network), Connect, then pair with `123456`. Step 3 (streaming) says it's skipped until Moonlight is in; step 4 checks everything and takes you to the library.

To see the mock in the Bonjour list too: `dns-sd -R "Steam Retriever (mock)" _steamretriever._tcp local 48080` in another Terminal tab.

Edge cases to poke while it runs:

```sh
curl -X POST localhost:48080/mock/sunshine/off      # paused banner, Play disabled
curl -X POST localhost:48080/mock/fail-next-launch  # launch error screen with Retry / Open Settings
curl -X POST localhost:48080/mock/stop              # game exits on the "Mac"
curl -X POST localhost:48080/mock/reset             # token revoked: app falls back to Setup > Pair
```

Against the real mini: address `mini.local` (or pick it from the list), and get the code from Steam Retriever's gear menu > Pair Apple TV... on the Mac.

## Layout

| Path | What |
|------|------|
| `SteamRetrieverTV/App/` | `AppModel` (splash → probe → Setup/Home → Launching → Streaming) and the app entry |
| `SteamRetrieverTV/API/` | API client and JSON models, matching `Sources/APIServer.swift` |
| `SteamRetrieverTV/Services/` | Keychain token + saved host, Bonjour discovery, Continue-shelf history |
| `SteamRetrieverTV/Streaming/` | `StreamLauncher` protocol; a preview stand-in until Moonlight is wired in |
| `SteamRetrieverTV/UI/` | Theme (Big Picture navy), Splash, Setup, Home (side nav, hero, shelves, search, game page), Launching |
| `Config/Info.plist` | Local-network HTTP, Bonjour services, local network prompt |
| `mock/` | Python mock of the API with sample games and covers |

The project uses a folder-synchronized group: drop a `.swift` file anywhere under `SteamRetrieverTV/` and it's part of the build, no project edits.

## Signing

None needed for the simulator. To run on the Apple TV, pick your team under Signing & Capabilities. That's left to Justin.

## License

GPL-3.0 (see `LICENSE`), because the app links moonlight-ios. The Mac app on `main` stays MIT. Personal use only for now.

## Talking to the mini chat

See `BRIDGE.md` on the `bridge` branch.
