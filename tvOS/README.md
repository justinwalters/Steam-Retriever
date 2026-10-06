# Steam Retriever for Apple TV

A tvOS app that shows the Steam Retriever library as a game grid, launches the chosen game on the Mac mini, and streams it with Moonlight from Sunshine. One app, no hopping to Steam Link.

This lives on branch **`tvos-app`** and only under `tvOS/`. It's built in Xcode on the MacBook Pro. The Mac app on `main` is untouched.

## Pieces

- `mock/` - a stdlib Python mock of the mini's API (contract: `CONTRACT.md` on the `bridge` branch). Run `python3 tvOS/mock/mock_server.py`, then point the app at `http://<macbook>.local:48080` with token `dev`.
- `moonlight-ios/` *(next)* - fork of moonlight-stream/moonlight-ios as a git submodule. It keeps its pairing, decode and controller input, and its host/app list gets replaced by our grid.
- App target *(next)* - API client, game grid (focus engine, cover art, description pane), and the launch → poll → stream flow. The style is dark steampunk with Sprocket, using art from `Art/`.

## License

The Mac app is MIT. Anything in `tvOS/` that links Moonlight is GPL-3.0, because moonlight-ios is. That's why this branch never merges into `main`. Personal use only for now.

## Talking to the mini chat

See `BRIDGE.md` on the `bridge` branch.
