# godot-gamecenter-ios

Reproducible build of the **GameCenter** iOS plugin from
[godot-sdk-integrations/godot-ios-plugins](https://github.com/godot-sdk-integrations/godot-ios-plugins) (MIT)
against **Godot 4.7.2**, for the Bubble Barrage game. Upstream publishes no release for Godot 4.7.

Output of a build: `gamecenter-godot4.7.2.zip` containing
`gamecenter/gamecenter.gdip`, `gamecenter/gamecenter.debug.xcframework`,
`gamecenter/gamecenter.release.xcframework` (device arm64 plus a fat arm64/x86_64 simulator slice),
`LICENSE` and `BUILD_INFO.txt`, with a `.sha256` next to it.

## Build

Run the **Build GameCenter plugin** workflow (macOS runner), or push a `v*` tag to also publish a release.
Locally on a Mac with Xcode and `pip install scons`: `./scripts/build.sh`.

`build/pins.env` pins the upstream plugin commit, the Godot tag and commit, and the minimum iOS version.
The Godot headers (including generated ones) come from a trimmed iOS engine build of that tag.

## Changes from upstream (`overlay/plugins/gamecenter/`)

- Sign-in and Game Center sheets find their presenting view controller when needed (engine window, then
  the key window of the connected scene), instead of failing if the window is not up at call time.
- Scores are submitted as integers with `+[GKLeaderboard submitScore:context:player:leaderboardIDs:completionHandler:]`
  rather than a float `GKScore`.
- The event queue is guarded by a mutex (GameKit completion handlers run off the main thread);
  `pop_pending_event()` on an empty queue returns nil instead of crashing; error events carry
  `error_description`.
- Deployment target raised to the game's minimum iOS version.

The script-facing API is unchanged: `authenticate()`, `is_authenticated()`, `post_score({score, category})`,
`award_achievement({name, progress, show_completion_banner})`, `show_game_center({view})`,
`get_pending_event_count()`, `pop_pending_event()` and the other upstream methods.

License: MIT, see `LICENSE` (Godot Engine contributors; upstream file kept verbatim).
