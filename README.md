# Forge — Personal Fitness OS for iPhone

Forge is a private, offline-first fitness application for a single user, built entirely
with native Apple frameworks. It tracks strength training, running, front/middle-split
flexibility work, weekly planning, body measurements and progress photos — and generates
rule-based, evidence-backed insights from your own data. No accounts, no backend, no
analytics, no third-party dependencies.

---

## Features

**Today dashboard** — today's planned sessions with one-tap start, weekly completion ring,
active-workout resume banner, body-weight sparkline, recent records, running & split
progress, recovery check and a suggested focus. Cards are individually toggleable and
reorderable in Settings.

**Exercise library** — ~40 built-in strength/bodyweight exercises plus unlimited custom
ones. Every field is editable: muscles (primary + secondary), category, equipment,
movement pattern, tracking flags (weight/reps/duration/distance/RPE), unilateral flag,
increment size, instructions, notes, image. Search, filters, favorites with reordering,
archive, duplicate, delete.

**Workout templates** — ordered exercises with planned warm-up/working sets, rep ranges,
target weight/RPE, superset groups, alternatives, color & icon, archive/duplicate.
Starter *Upper Body* and *Lower Body* templates are seeded and fully editable.

**Live workout tracking** — previous-session performance and PB shown per exercise,
planned targets per set, quick ± weight/reps adjustments using each exercise's increment,
RPE selector, set types (warm-up, working, back-off, drop, failure, custom), add/delete
sets, add/replace/reorder/remove exercises mid-workout, notes, pause/resume, elapsed time
excluding pauses. **Everything autosaves continuously through SwiftData** — force-quitting
loses nothing; the session is offered for resume on next launch. Finishing captures date
(editable), 1–5 rating, energy/soreness scores and final notes.

**History** — list and calendar views, full-text search across workout and exercise names,
muscle filter, per-session volume/hard-sets/average-RPE, records set in that session,
edit past sessions (records recalculate), duplicate, delete, repeat as a new workout,
save any session as a template.

**Running** — manual logging with distance, duration, computed pace, splits, intervals,
surface, route type, RPE, heart rate, calories and run types (easy/tempo/interval/
time-trial/recovery/long/custom). Benchmark chips for 100 m, 1 km, 3 km, 5 km, 10 km with
per-distance personal bests, weekly volume and pace-trend charts, a user-defined goal, and
a deliberately conservative 3 km projection (clearly labeled an estimate). Optional
HealthKit import of running workouts with duplicate protection.

**Flexibility** — editable starter routines for **front split**, **middle split** and
**light mobility** (plus custom routines), each item with hold time, sets, left/right or
bilateral mode, rest and instructions. Guided live sessions with a hold/rest timer ring,
side indicator, skip/back/pause, and completion logging with discomfort rating. Progress
measurements per split (left front / right front / middle) via floor distance, hip height,
block height, angle or subjective score — charted over time with "lower is better"
handled correctly.

**Weekly schedule** — preset-based plans (multiple presets, one active), any number of
sessions per day, linked templates/routines. Week-specific overrides: complete, skip,
move to another day, or add one-off activities **without touching the base plan**.
Sessions you actually log are auto-matched to the plan. Past/future week browsing,
missed-session detection, weekly completion rate.

**Body & photos** — 12 built-in measurements plus custom ones, unit-aware entry, trend
charts, weekly/monthly averages and range deltas. Private progress photos (front/side/
back/custom) stored inside the app at reduced size with original aspect ratio, tags,
weight stamps, and side-by-side comparison. Photos are never analyzed or altered.

**Analytics** — selectable ranges (30d/90d/6m/1y) across strength (weekly tonnage,
per-exercise estimated 1RM, hard sets per muscle, RPE trend), running (weekly distance,
pace, 3 km times), flexibility (session frequency, split measurements) and consistency
(schedule adherence, total weekly activity). Every estimate is labeled as an estimate.

**Personal records** — heaviest weight, most reps at top weight, estimated 1RM, session
volume, fastest benchmark times, best pace, longest run, best split measurements, longest
weekly streak. Records are **recomputed from raw history** whenever sessions change, so
editing or deleting old data always yields correct records.

**Insights (AI progress assistant)** — a modular, on-device rules engine (no API, no
cost) that analyzes your stored data: progressive-overload opportunities, stalled lifts,
rising RPE with falling output, sustained high effort (deload suggestion), missed-session
patterns, muscle-group imbalance, running improvement/plateau, flexibility consistency,
schedule conflicts, and conservative 4-week projections. Every insight shows its evidence
("Why am I seeing this?"), can be dismissed (dismissals persist until the evidence
changes), and every category can be disabled. The engine consumes plain value-type
snapshots, so a hosted AI model could be swapped in later without persistence changes.

**Settings** — units (kg/lb, km/mi, cm/in — data is stored metric and never mutated by
unit switches), default increment, RPE visibility, first weekday, dashboard cards,
custom catalogs (muscle groups, equipment, run types, stretch areas, body metrics,
activity types), haptics, Face ID app lock, HealthKit, notifications, running goal.

**Data** — JSON backup (optionally including photos), CSV export (per-set workouts, runs,
measurements), validated restore that **merges by ID** (duplicates skipped, nothing
silently destroyed), corrupted-file handling with readable errors, and delete-all behind
a typed "DELETE" confirmation.

---

## Architecture

- **UI**: SwiftUI, iOS 17+, dark-first design system (`DesignSystem/`) with color,
  typography, spacing and radius tokens, shared card/button/input components, and
  centralized haptics.
- **Persistence**: SwiftData (`Models/`, `Persistence/`). All enums stored as raw strings
  (predicate-safe, CloudKit-friendly), to-one relationships optional, to-many arrays with
  explicit `sortIndex` ordering. Historical sessions **snapshot** exercise names, muscle
  groups and targets, so editing templates or the library never rewrites history.
- **Domain logic**: `Core/` is pure Swift with zero SwiftData imports — strength math
  (Epley/Brzycki-averaged e1RM capped at 12 reps), pace math, conservative Riegel
  predictions, linear-regression trend analysis, PR detection, adherence math, the
  insights rules engine, and versioned backup DTOs + validation. This layer is what the
  unit tests exercise.
- **Services**: `Services/` bridges the two — snapshot mapping, workout lifecycle,
  schedule resolution (preset ⊕ overrides ⊕ auto-completion), PR cache recompute,
  insights refresh with fingerprint-based dismissal persistence, HealthKit, notifications,
  export/import, app lock.
- Pattern: SwiftUI-native MVVM — `@Query`/`@Observable`/`@Bindable` replace hand-rolled
  view models; stateful flows (live workout, live stretching) keep their state machines
  in the view layer backed by autosaving models; all business rules live in `Core`.

```
Forge/
├── App/                  ForgeApp, RootView (tabs, app lock)
├── Models/               SwiftData @Model classes + enums
├── Persistence/          Container factory, seed data, preview sample data
├── Core/                 Pure logic: math, trends, PRs, insights, backup
├── DesignSystem/         Tokens + reusable components + haptics
├── Services/             Workout/schedule/PR/insights/HealthKit/notifications/export
├── Features/             Today, Workouts, ExerciseLibrary, Templates, LiveWorkout,
│                         History, Running, Flexibility, Schedule, Body, Photos,
│                         Progress, Insights, Settings, Onboarding
└── Utilities/            Formatting, image processing
ForgeTests/               Unit + store-integration tests (XCTest)
ForgeUITests/             UI tests (run with -UITestMode, in-memory store)
```

---

## Requirements

- **Xcode 16.0 or newer** (the project uses Xcode 16 file-system-synchronized groups —
  older Xcode versions cannot open it)
- **iOS 17.0+** deployment target (SwiftData, `@Observable`)
- Swift 5 language mode; no packages, no third-party dependencies

## Opening & running

1. Open `Forge.xcodeproj` in Xcode 16+.
2. Select the **Forge** scheme and an iPhone simulator (or device) and Run.
   The simulator needs no signing configuration changes for most setups.
3. First launch shows a short onboarding (units, focus, integrations) and seeds the
   editable starter content (exercise library, two templates, three flexibility
   routines, one weekly plan).

### Manual Xcode setup for a device build

- **Signing**: Targets → Forge → Signing & Capabilities → select your Team. Change
  `PRODUCT_BUNDLE_IDENTIFIER` (default `com.personal.forge`) to something unique.
- **HealthKit**: the entitlement and both privacy strings
  (`NSHealthShareUsageDescription`, `NSHealthUpdateUsageDescription`) are already
  configured. With automatic signing, Xcode registers the capability when a team is set.
  If you don't want HealthKit at all, delete the two keys from build settings and the
  entries in `Forge/Forge.entitlements`.
- **Face ID**: `NSFaceIDUsageDescription` is configured; nothing else needed.
- **Notifications**: local notifications only; permission is requested in-app on opt-in.
- **iCloud sync (optional, off by default)**: the schema is CloudKit-compatible
  (optional to-one relationships, defaults everywhere, no unique constraints). To enable:
  1. Signing & Capabilities → add **iCloud** → check **CloudKit** → create a container.
  2. Add the **Background Modes → Remote notifications** capability.
  3. In `Persistence/ModelContainerFactory.swift`, create the `ModelConfiguration` with
     `cloudKitDatabase: .automatic`.
  The app remains fully functional without iCloud or when it is unavailable.

## Testing

- `⌘U` in Xcode runs everything, or:
  ```
  xcodebuild test -project Forge.xcodeproj -scheme Forge \
    -destination 'platform=iOS Simulator,name=iPhone 16'
  ```
- **ForgeTests** (unit + integration, in-memory SwiftData store): e1RM, volume and RPE
  math; pace, formatting and conservative Riegel predictions; unit conversions; trend
  fitting and direction thresholds; adherence math incl. first-weekday handling; PR
  detection (strength/running/flexibility/streaks, incl. records updating after history
  edits); every insight rule (positive and negative cases, category filtering, stable
  fingerprints, capped projections); backup encode/decode round-trip, corruption,
  future-schema rejection, semantic validation, CSV escaping; seeding idempotence;
  session lifecycle (targets prefilled, crash recovery, pause math, records on finish);
  template edits never altering history; schedule resolution (auto-completion, skip/move
  overrides isolated to their week); restore merge de-duplication; delete-all.
- **ForgeUITests** launch with `-UITestMode` (in-memory store, onboarding skipped):
  tab navigation, create exercise, start/finish empty workout, template workout with a
  completed set, run logging, body-measurement entry, schedule and settings navigation.

## Privacy & data storage

- All data lives in the app's private SwiftData store on device (images use SwiftData
  external storage). No analytics, tracking, ads, remote uploads or third-party SDKs.
- Progress photos are copied into private storage at reduced resolution (originals
  untouched), never analyzed, and only leave the app if you export them yourself.
- HealthKit is opt-in, read-only by default, explains each permission, marks imported
  entries, prevents duplicate imports, and never blocks app use when denied.
- Optional Face ID/passcode lock covers the UI whenever the app backgrounds.
- Backups are created only on your explicit action and go wherever you share them.

## Backup & restore

- **JSON backup**: versioned schema (`schemaVersion`), ISO-8601 dates, human-readable.
  Photos included only when toggled on.
- **Restore**: files are decoded and validated first (schema version, duplicate IDs,
  value ranges); you're shown exactly what the file contains before merging. Restore
  merges by stable UUID — existing records are skipped, never overwritten; restoring the
  same file twice is harmless.
- **CSV**: one row per set (workouts), per run, and per measurement, RFC-4180 escaping.

## Continuous integration (verified build & tests)

`.github/workflows/ios-ci.yml` builds and tests Forge on a GitHub-hosted macOS runner
on every push to the development branch (plus manual dispatch and PRs to `main`).
Verified result on **macOS 15.7, Xcode 16.4 (16F6), Swift 6.1.2, iPhone 17 Pro
simulator**:

- App target: **builds cleanly — zero Swift compiler errors and zero Swift source
  warnings** (`** BUILD SUCCEEDED **`)
- Unit tests (`ForgeTests`): **68 passed, 0 failed, 0 skipped** (`** TEST SUCCEEDED **`)
- UI tests (`ForgeUITests`): **8 passed, 0 failed** (`** TEST SUCCEEDED **`)
- Full logs and `.xcresult` bundles are uploaded as the `forge-ios-ci-diagnostics`
  artifact on every run (kept 14 days), including failed runs.

Simulator builds run with `CODE_SIGNING_ALLOWED=NO`; no certificates, profiles, team
IDs or secrets are stored in the repository.

## Known limitations
- iCloud sync requires the manual capability setup described above.
- HealthKit strength-workout writing records duration only (sets/reps stay in Forge).
- Rest timers are intentionally minimal (a hold/rest timer exists for flexibility
  sessions; strength logging is timer-free by design).
- Insights are heuristic rules — useful, conservative, and clearly evidence-labeled, but
  not a coach and not medical advice.
- UI tests cover primary flows; deep-link/edge-gesture flows are untested.

## Recommended next improvements

1. Install on a physical iPhone (signing steps above) and verify Face ID, HealthKit,
   notifications and PhotosPicker on-device.
2. Enable CloudKit sync (steps above) and test two-device merge behavior.
3. Add a widget (today's plan + week ring) and Live Activity for active workouts.
4. Add plate-math calculator and bar-loading hints in the live workout.
5. Photo export bundling (zip) and encrypted backups.
