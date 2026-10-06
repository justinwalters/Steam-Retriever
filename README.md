# Steam Retriever

A small, fast, native macOS app that fetches your games for you. It keeps **macOS Steam** and **Windows Steam (CrossOver)** libraries on one external drive, shows them in a single searchable launcher with cover art and short descriptions, and starts each game in the right environment.

While Steam wakes up, a golden retriever pup named **Sprocket** (goggles, a boiler pack and a convention badge) plays in a steampunk park right inside the window.

## What it does

- **One library, two Steams.** Scans `steamapps` on a `STEAM` volume (`Mac/` and `Windows/`) and shows every installed game with cover art, developer, genres and a description short enough to read in full.
- **Starts games the right way.** Mac games through macOS Steam, Windows games through a CrossOver bottle named `Steam`. Games that do not need Steam can start directly.
- **Quiet start.** Steam starts without its windows (`-silent -nofriendsui -no-browser`).
- **Keeps Steam warm, switches cleanly.** Steam stays running after a game closes, so the next game on the same side starts fast. Choosing a game on the *other* side checks which Steam is running and closes it first.
- **Idle close.** With nothing playing or starting for five minutes, running Steam clients are closed.
- **Failsafes.** The launcher watches each start: it re-sends the launch if Steam ignores it, restarts Steam if it dies or stalls, and escalates to a force quit if Steam will not close.
- **Fetching dialog.** Sprocket does nine random 10-15 second tricks (fetch, zoomies, speedrunning, roll over, digging, tail chasing, playing dead, backflips, a clockwork butterfly), including running off-screen and into the distance.

## Build

Needs macOS 14+ and the Xcode command line tools (`xcode-select --install`). No Xcode project.

```sh
./build.command
```

This compiles `Sources/*.swift` with `swiftc`, copies the art from `Art/`, makes the icon, ad-hoc signs the app and installs **Steam Retriever.app** into `~/Applications`.

## Layout

- `Sources/` - the Swift app (SwiftUI): library scan, launcher/supervisor, pup choreography and stage.
- `Art/` - generated pup parts, park backdrop and icon.
- `art-source/` - the HTML canvas scripts that paint the art (`export.py` renders them with Playwright).

## License

MIT
