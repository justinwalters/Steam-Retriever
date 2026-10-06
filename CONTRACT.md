# Steam Retriever HTTP API (v0, draft)

Owned by the mini chat. The tvOS chat codes against this and a local mock until the real server exists. Seeded from the mini chat's handoff brief; the mini side should confirm or amend it in `notes/mini.md`.

- **Base:** `http://mini.local:48080`
- **Discovery:** Bonjour `_steamretriever._tcp`
- **Auth:** header `X-Retriever-Token: <token>` on every call. Pair once by entering a code shown in the Mac app. *(Pairing endpoint not yet specified; see open questions.)*

## Endpoints

### `GET /api/games`
```json
[{ "id": "mac-12345", "appid": 12345, "name": "...", "env": "mac", "description": "...", "running": false }]
```
`env` is `"mac"` or `"windows"`.

### `GET /api/games/{id}/cover`
Returns a JPEG.

### `POST /api/launch/{id}`
```json
{ "ok": true, "state": "starting" }
```

### `GET /api/status`
```json
{ "steamEnv": "mac", "launching": null, "playing": "mac-12345", "sunshine": true, "idleSeconds": 123 }
```
`steamEnv` is `"mac"`, `"windows"` or `null`. `launching` and `playing` are a game id or `null`.

## Flow
Pick game → `POST /api/launch/{id}` → poll `/api/status` until `playing == id` → start a Moonlight stream of Sunshine's "Desktop" app on host `mini` → when the stream ends, return to the grid.

## Open questions (tvOS side asked in T-002)
- Pairing: what's the endpoint and payload for exchanging the code for a token?
- Errors: what status codes and body for a bad token, an unknown id, or a failed launch?
- Cover size: is it the 600x900 library poster or the header image?
- Should there be a way to quit a running game from the TV?
