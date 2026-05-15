# Sound Assets

All MP3 files dropped into this folder are automatically bundled
(`pubspec.yaml` declares the whole `assets/sounds/` directory).

## Ambient loops (played while a focus / break phase is running)

Mono or stereo, 44 kHz, ≤ 2 MB recommended. Looped via `LoopMode.all`.

| File                | Description                        |
|---------------------|------------------------------------|
| `lofi.mp3`          | Lo-fi study beats loop             |
| `rain.mp3`          | Gentle rain / rainfall loop        |
| `white_noise.mp3`   | Broadband white-noise loop         |
| `cafe.mp3`          | Ambient café / coffee-shop loop    |

## Completion chimes (played once when a phase ends)

Short (1–3 seconds), pleasant, NOT looped. The first one is also copied to
`android/app/src/main/res/raw/complete_chime.mp3` so it can be used as a
custom sound on the scheduled background notification.

| File                       | Description                |
|----------------------------|----------------------------|
| `complete_chime.mp3`       | Gentle bell / chime (default) |
| `complete_ding.mp3`        | Sharper ding / alarm       |

Free sources: freesound.org, pixabay.com/music, zapsplat.com
