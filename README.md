# Dino Jungle

A little game for a preschooler: fly a helicopter freely over a volcano island and meet the dinosaurs.
Realistic CC0 dinosaurs (Grab3D) wander, graze and rest; tap one nearby to hear its name and a fun fact,
and collect it in the Dino Book. FIND A DINO! flies you to the next one, ROAR! makes the nearest herd roar.

- Left stick: faster / slower (stays where you leave it). Right stick: turn, climb, dive. It can't crash.
- The island is generated in Blender: `scripts/make_jungle_terrain.py`; heavy models are slimmed for
  tablets with `scripts/slim_model.py`; the app icon is rendered by `scripts/make_icon.gd`.
- The local build flies a helicopter from another of my games that isn't licensed for sharing, so it is
  not in this repo; a clone flies the CC0 helicopter by kazuma instead.

## Build

Godot 4.7 (GL Compatibility renderer), one project for iPhone/iPad and Android.

```bash
cp scripts/devices.env.example scripts/devices.env   # your iPhone ids, Apple team, tablet serial/IP
scripts/build.sh iphone   # iOS export -> xcodebuild -> install on the iPhone
scripts/build.sh fire     # Android export -> adb install on the tablet (Wireless debugging on)
scripts/build.sh sim      # iOS simulator (Godot's simulator library is x86_64: runs under Rosetta)
```

Android export needs Java: `JAVA_HOME` defaults to Android Studio's bundled JDK. Desktop test with
screenshots: `cd godot && godot --resolution 1280x800 -- --autoplay=/tmp/shots`.

## Assets

Everything bundled is CC0, see `assets-src/CREDITS.md` for each source. The raw downloads in
`assets-src/` are not committed (they are large); the game only needs `godot/assets/`.
Code: MIT (`LICENSE`).
