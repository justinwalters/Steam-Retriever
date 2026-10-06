# Steam Retriever for Apple TV: MacBook session brief

## Goal
A tvOS app that shows my game library (same grid as the macOS app "Steam Retriever"), launches the chosen game on my Mac mini, then streams the mini's screen to the Apple TV over the home network. One app, no hopping to Steam Link.

## Machines
- **Mac mini** ("mini", user justinwalters): runs the macOS app Steam Retriever (Swift/SwiftUI, repo https://github.com/justinwalters/Steam-Retriever, covers/art in Art/). It launches Mac games via native Steam and Windows games via Steam in a CrossOver bottle, and manages which Steam is running. Another Claude session works there.
- **Sunshine** (LizardByte, GPL-3.0) runs on the mini as the stream host (ScreenCaptureKit capture, gamepad via Virtual HID Broker).
- **MacBook Pro** (this machine): has Xcode. Your job is the tvOS app.

## Streaming plan
Fork https://github.com/moonlight-stream/moonlight-ios (GPL-3.0; has a tvOS target). Keep its pairing, video/audio decode and controller input. Stream Sunshine's default "Desktop" app, so no per-game Sunshine entries are needed. Replace its host/app list with our game grid.

## API contract (implemented in Steam Retriever on the mini; code against it, mock it until you can reach the mini)
Base: http://mini.local:48080 (also advertised over Bonjour as _steamretriever._tcp, port 48080). Plain HTTP on the home network.
Auth: header `X-Retriever-Token: <token>` (or `?token=` for image URLs). Only /api/ping and /api/pair are open.
- GET /api/ping -> { "app": "Steam Retriever", "api": 1 }
- POST /api/pair  body {"code":"123456","name":"Apple TV"} -> { "token": "..." }. The user first chooses gear > "Pair Apple TV..." in the Mac app, which shows a 6-digit code for 5 minutes (5 wrong tries cancels it). Store the token in the Keychain.
- GET /api/games -> [{ "id":"mac-12345", "appid":12345, "name":"...", "env":"mac"|"windows", "description":"...", "shortDescription":"...", "genres":[...], "developer":"...", "released":"...", "sizeBytes":123, "installedAt":1700000000, "running":false, "starting":false }]. Descriptions are fetched in the background the first time, so empty strings can appear on a first call; re-fetch after a few seconds.
- GET /api/games/{id}/cover?kind=poster|header -> JPEG (poster is portrait, header is landscape; falls back automatically). Cacheable.
- POST /api/launch/{id} -> 200 { "ok": true, "state": "starting"|"playing" } or 409 { "ok": false, "error": "Finish <game> first." }
- GET /api/status -> { "steamEnv":"mac"|"windows"|null, "steam":{"mac":bool,"windows":bool}, "launching":id|null, "playing":id|null, "sunshine":bool, "steamClosesInSeconds":int|null }
Flow: user picks a game -> POST launch -> poll /api/status every 2 s until `playing == id` (can take 30 to 120 s, longer if Steam has to switch environments or cold start; give up after about 6 minutes) -> start the Moonlight stream of Sunshine's "Desktop" app from host "mini". When the stream ends, return to the grid. Sunshine runs as a login service on the mini; if status.sunshine is false, tell the user it is paused.
The Mac app must be running for the API to answer; by default it keeps running after its window is closed.


## App behavior and UX spec (decided with Justin)
Goal: once configured, opening the app drops straight into "Steam Retriever Big Picture", our own native tvOS game browser styled after Steam's Big Picture. No server picker, no Moonlight host list in normal use.

### Launch flow
1. App opens with a short splash (Sprocket the golden retriever pup is the mascot; art is in the Steam-Retriever repo, Art/ folder).
2. If a host address and token are stored: call GET /api/ping (2 s timeout), then GET /api/status. If both answer and the token is accepted, go straight to Home. Also browse Bonjour for _steamretriever._tcp and _nvstream._tcp (Sunshine); if the stored host shows up, skip everything and go to Home immediately. Don't block on Bonjour; use whichever answers first.
3. If anything fails (no host, ping times out, 401 on the token, Sunshine not paired), show the **Setup** screen with the failed step marked and a plain-language reason, so it can be fixed from the couch. Never dead-end on a spinner: every wait has a timeout and a "Settings" button.
4. Setup is also always reachable from Home > Settings.

### Setup screen (all on the Apple TV, no phone needed)
1. **Find the Mac**: list from Bonjour plus a manual address field (mini.local or an IP).
2. **Pair Steam Retriever**: user opens the Mac app's gear menu > "Pair Apple TV...", types the 6-digit code here -> POST /api/pair, store token in the Keychain.
3. **Pair streaming (Sunshine)**: reuse Moonlight's pairing code path; show the 4-digit PIN large on screen; user enters it in Sunshine's web UI (https://localhost:47990, PIN tab) on the Mac. One time only.
4. **Test**: ping, token check, Sunshine check, then a short test stream of "Desktop". Show a green check per step and the failing step in red with a one-line fix.

### Home: Steam Big Picture style
Keep as much of Big Picture's feel as possible, without Valve's logos or artwork (their trademarks):
- Dark navy palette (about #171D25 background, #1B2838 panels, #2A475E accents, #66C0F4 highlight), big soft-edged tiles, generous spacing, focus = tile scales up with a glow.
- **Left side nav** (Moonlight-like): Home, Library (all games), Mac, Windows, Now Playing, Settings. Siri Remote swipe or controller d-pad moves focus; Select opens; Menu goes back.
- **Hero banner** for the focused game: header art, name, developer, genres, short description, big **Play** button, and a small "Mac" or "Windows" badge.
- **Shelves** on Home: Continue (last played, tracked locally on the Apple TV), Recently added, All Games; poster covers from /api/games/{id}/cover.
- Search by dictation or on-screen keyboard.
- A banner when `status.sunshine` is false ("Sunshine is paused on the Mac"); browsing still works, Play is disabled with the reason.

### Playing
1. Play -> POST /api/launch/{id}. Show a progress screen with Sprocket and the live state from /api/status (starting Steam, switching environment, game starting). Polling every 2 s, timeout about 6 minutes.
2. When `playing == id`, start the stream of Sunshine's "Desktop" app. Controllers go through Moonlight's input path to Sunshine's virtual gamepad.
3. During the stream, the Menu long-press or Menu+Play opens an overlay: Return to library, Stream settings. Ending the stream returns to the library; the game keeps running on the Mac (the Mac app closes Steam after 5 idle minutes by itself).
4. If launching or streaming fails, show the error with Retry and "Open Settings" (which goes to the Setup screen at the failing step).

### Out of scope for now
Remote access away from home (would use Tailscale later), multiple Macs, App Store release (GPL-3.0 applies to the Moonlight-derived code).

## Your first steps
1. Clone moonlight-ios, build the tvOS target, run it in the tvOS simulator, confirm it compiles on current Xcode.
2. Add a Swift client for the API above plus a local mock server (Python or Swift) returning sample games, so the grid can be built before the mini side exists.
3. Build the game grid screen (tvOS focus engine, cover art, description pane). Style: dark steampunk look to match the Mac app; mascot is a golden retriever pup named Sprocket; art is in the repo's Art/ folder.
4. Wire launch -> poll -> stream. Test streaming with the stock Moonlight app against Sunshine on the mini first.
5. Remember GPL-3.0: the fork stays GPL-3.0. Personal use only for now.

## Notes
- The API is plain HTTP, so the tvOS app needs an App Transport Security exception for local networking (NSAppTransportSecurity > NSAllowsLocalNetworking = YES) and an NSLocalNetworkUsageDescription plus NSBonjourServices [_steamretriever._tcp] in Info.plist.
- Moonlight discovers the Sunshine host by itself; our app only needs to hand off to it after the game is up.

## Ground rules
Prefer small, reviewable commits on a branch. Ask me before anything that touches my accounts, the App Store, or signing certificates.
