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
  chosen. All six ink/ground pairs clear 7:1; the derived neutral clears 4.5:1
  on all six grounds.
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

## Not done

- Nothing has been built or run (see above).
- iPad and landscape are supported, not optimised, as asked.
