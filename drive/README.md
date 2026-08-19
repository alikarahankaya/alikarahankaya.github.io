# Drive

An iOS app that records a drive with no interface during the drive, and
afterwards turns it into one object: the shape of the road, the rhythm of its
corners, and the light it was driven in.

The product name lives in exactly one place — `CFBundleDisplayName` in
`App/Info.plist`. Nothing in the code knows it.

---

## Status: not yet compiled

This was written in a Linux container with no Swift toolchain and no network
route to one (`download.swift.org` is blocked by the environment's network
policy). **No file here has been through a compiler, and no test has been
run.** Expect to spend a first pass fixing what a compiler would have caught.

What *has* been checked, because it was checkable without Swift:

- The analysis pipeline was written twice: once in Swift, and once as a
  reference implementation in `Tools/reference_pipeline.py`. The Python version
  was run against the fixtures and against synthetic circles, and every number
  asserted in `Tests/AnalysisTests` is a measured output of that run, not a
  guess. Curvature came out within 0.7% of 1/r for radii from 12 m to 400 m.
- The palette's contrast ratios were computed before the hex values were
  chosen. Type clears 7:1 in all six lights (9.7–13.0:1), the orange clears the
  3:1 graphics floor (3.7–8.1:1), and the derived neutral clears 4.5:1
  (5.0–7.6:1) on every ground.
- The solar position algorithm was checked against published altitudes
  (London midsummer noon 61.9°, Sydney midwinter noon 32.7°).

## Layout

```
Sources/
  Core          value types and pure vector maths: Sample, Vector3,
                VehicleFrame and its solver, Coordinate, Geo
  GPX           GPX in, [Sample] out
  Analysis      [Sample] -> DriveAnalysis. Pure. No I/O, no clock, no
                CoreLocation. Where all the interesting work lives
  Storage       SwiftData. Stores blobs; does not know what is in them
  Capture       CoreLocation, CoreMotion, ActivityKit, WeatherKit
  Presentation  SwiftUI. Reads analysis output
  Fixtures      four synthetic GPX roads, shared by the test targets
App/            the app target and its Live Activity widget
Tools/          fixture generator and the Python reference pipeline
```

The dependency arrows only ever point at `Core`, and at `Analysis` from
`Presentation`. Capture knows nothing about analysis; analysis knows nothing
about anything.

Five directories rather than the brief's four: `Core` exists so `Capture` can
produce a `Sample` without importing `Analysis` to get the type.

## Getting it into Xcode

There is no `.xcodeproj` in the repository — one could not be produced or
verified here. Ten minutes, once:

1. **New project** → iOS → App. Interface SwiftUI, language Swift, no tests
   (the package brings its own). Set the deployment target to iOS 18.
2. **Add the package**: File → Add Package Dependencies → Add Local, and
   choose this `drive` directory. Link `Core`, `Analysis`, `Storage`,
   `Capture` and `Presentation` to the app target.
3. **Replace the generated app sources** with the files in `App/`
   (`DriveApp.swift`, `DriveLibrary.swift`, `RootView.swift`,
   `DebugReplay.swift`), and use `App/Info.plist` and `App/App.entitlements`.
4. **Signing & Capabilities**: add Background Modes → Location updates, and
   WeatherKit. WeatherKit also has to be enabled for the App ID in the
   developer portal.
5. **Widget extension**: File → New → Target → Widget Extension, tick "Include
   Live Activity". Replace its source with `App/Widget/DriveActivityWidget.swift`
   and link the `Capture` library to it (that is where the activity attributes
   live).
6. Swift 6 language mode is set per target in `Package.swift`; set it for the
   app target too, under Build Settings → Swift Language Version.

## Tests

Everything is Swift Testing. The package targets iOS only — `Capture` and
`Presentation` import frameworks that do not exist on macOS — so run them
against a simulator:

```sh
xcodebuild test -scheme DriveKit \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

`Tests/AnalysisTests` is the part worth reading. It proves, on geometry whose
answer is known in advance, that a circle of radius r reads 1/r, a hairpin
resolves as one corner rather than three, a motorway has no corners at all,
and a straight line has sinuosity 1.0.

## Fixtures

Four synthetic roads, built from exact straights and constant-radius arcs:

| Fixture | What it is | What it should produce |
|---|---|---|
| `hairpin-pass` | eight hairpins, climbing, at dusk | 8 corners, first one isolated, severity 1, 130 m of climb |
| `sweepers` | eight constant-radius bends, morning | 7 corners — the 500 m one is too open to count |
| `motorway` | 10 km, two 2 km-radius bends, midday | no corners, sinuosity 1.00 |
| `urban` | right angles and a stop at every junction, night | 8 corners, almost no flow |

Regenerate with:

```sh
python3 Tools/make_fixtures.py           # writes Sources/Fixtures/GPX/*.gpx
python3 Tools/reference_pipeline.py      # prints what the pipeline should find
```

The Python is a development tool, not part of the app. It exists so the
constants in `Analysis/Tuning.swift` could be argued with before they were
committed to.

## Colour

White and orange, and one of each.

| Role | What it is | Where it appears |
|---|---|---|
| ground | white, or near-black after dark | every screen |
| ink | deep burnt orange, or warm apricot at night | type only |
| signal | vivid orange | every line: trace, rhythm strip, live ribbon |
| neutral | the ink, three quarters back to the ground | secondary type |

Two surfaces rather than six palettes: white by day, its inverse at night,
because a white screen in a dark car is glare rather than design. The six
lights survive as the ground's tint and the orange's warmth, so a library
still sorts itself by the light each drive was made in.

The orange is two weights of one hue on purpose. A vivid orange cannot carry
type at 7:1 on white — it tops out near 3:1 — so type uses the ember and lines
use the signal. `PaletteTests` proves every ratio.

## The screen while driving

One line, and a number that is not always there.

The line runs left to right through the last forty-five seconds. It rises when
you accelerate, falls when you brake, and thickens with how hard the car is
cornering — the same variable-weight stroke the artifact draws, with time on
the axis instead of distance. At a steady cruise it flattens to a hairline and
the number disappears, so the screen empties itself without being told to.

The number appears only above 0.25 g and reads in the quiet neutral, not the
orange. Nothing on this screen has to be read, there is no control to hit, and
the only gesture is a long press anywhere to end the drive — during which the
whole ribbon fades out, so the screen answers the gesture rather than a
progress ring answering it.

Not there, deliberately: speed, distance, elapsed time, corner count, a map. 
Elapsed time is on the lock screen, where it costs nothing. Each of the others
would be a reason to look down.

Before the phone has worked out its orientation in the car there is no way to
tell cornering from braking, so the ribbon draws a flat line and says nothing
rather than guessing.

## Where this departs from the brief

Each of these is also commented at the point it happens.

- **Five modules, not four.** `Core` holds the shared value types.
- **Sinuosity is measured over rolling kilometres**, not end to end. Drives
  that come home again have endpoints metres apart, and the literal definition
  returns infinity for them.
- **Resampling carries the lowest speed seen.** Resampling by distance steps
  straight over a stop, and flow needs to know about stops.
- **The sample rate is whatever CoreLocation gives**, about 1 Hz on current
  phones rather than the 10 Hz the brief assumes. Nothing downstream depends
  on it; analysis resamples by distance. The IMU runs at 50 Hz and is averaged
  down to each fix.
- **The smoothing window is 21 m, not ~30 m.** Measured: 31 m flattens a 12 m
  hairpin by about 15%.
- **There is a screen during the drive**, which the brief's one design rule
  forbade. Reversed at the author's request; designed so that nothing on it
  needs reading (see above).
- **One palette modulated by light**, rather than six bespoke ink/ground
  pairs, following the move to white and orange.

## Not done

- Nothing has been built or run (see above).
- iPad and landscape are supported, not optimised, as asked.
