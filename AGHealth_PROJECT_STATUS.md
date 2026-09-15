# AGHealth — Project Status

**This file is the short operational source of truth for AGHealth's current state.** Read it first, every time, before starting any new AGHealth task. See §10 for the full rules.

Last updated: 2026-09-15 14:20 MSK (added permanent Agent Workflow / Checkpoint Rules — see §10; no code changed).

---

## Current Task Checkpoint

Task: Exercise management (per-workout delete + exercises directory CRUD)

Goal:
- Swipe-left delete of an exercise from one specific strength workout — removes only that exercise's sets from that workout; the global exercise record and all other workouts stay untouched; the exercise remains selectable in the picker afterwards.
- Exercise picker (`ExercisePickerView`) becomes selection-only — no delete/edit/archive inside it.
- New "Еще → Упражнения" screen (separate `ExercisesView.swift`) with full CRUD over the global exercise catalog: view, create, edit, archive/delete.
- Global `DELETE /api/v1/fitness/exercises/:id` is reserved for the global archive/delete action inside the new Упражнения screen only — never for per-workout removal.
- Explicitly excluded: manual "create workout from scratch" / `AGH-20`, any UI redesign.

Phase: Phase 0 complete (investigation); Phase 1 (backend endpoint) is next.

Status: IN PROGRESS (investigation DONE; implementation NOT STARTED)

Phase 0 — Investigation of current code (this session): DONE
Phase 1 — Backend endpoint (delete exercise from one workout): NOT STARTED
Phase 2 — StrengthWorkoutView / picker cleanup: NOT STARTED
Phase 3 — WorkoutDetailView swipe-to-delete: NOT STARTED
Phase 4 — Exercises directory (`ExercisesView.swift` + Ещё menu entry): NOT STARTED
Phase 5 — Tests + docs rewrite + commit + push: NOT STARTED

Completed:
- Full read-only investigation of both repos (iOS `aghealth-work` + backend inside `openclaw-backup`). No functional code was changed this session — see Findings below.

In progress:
- (none — this was investigation only; there are no partial/half-done edits anywhere)

Not started:
- Backend: new endpoint to delete all sets for one `(workoutId, exerciseId)` pair.
- iOS: `StrengthWorkoutView.swift` cleanup — remove the trash button, `onDelete` closure, confirmation dialog, and `isDeleting`/`deleteErrorMessage`/`exercisePendingDeletion` state from `ExercisePickerView`/`ExercisePickerRow`; delete the now-unused `deleteExercise(_:)` helper and its wiring in `StrengthWorkoutView`.
- iOS: `WorkoutDetailView.swift` — add swipe-to-delete per exercise group (`ExerciseGroupCard`), calling the new endpoint, with a confirmation dialog and a detail refresh on success.
- iOS: new `Fitness API/UI/ExercisesView.swift` (list + create + edit + archive/delete of the global catalog), using the backend's already-existing `POST`/`PATCH`/`DELETE /api/v1/fitness/exercises` endpoints. `APIClient.swift` currently only has `deleteExercise(id:)` — `createExercise(...)` and `patchExercise(...)` methods still need to be added.
- `MoreSectionView.swift`: add a "Упражнения" `NavigationLink` (e.g. in the "МОИ ДАННЫЕ" section, next to "Питомец").
- Backend tests for the new endpoint.
- A real rewrite of §4/§5/§7/§11 of this file once the feature actually ships (this checkpoint is not that rewrite).

Findings (factual, verified this session — do not re-derive these from scratch):
- iOS repo `goryaynova/AGHealth`; canonical local clone is `/root/.openclaw/workspace/aghealth-work` (NOT `/tmp/AGHealth`, a stale second clone with an old unpushed commit — see §9). `git status` is clean and in sync with `origin/main` at `82c9737`.
- `StrengthWorkoutView.swift` → `ExercisePickerView`/`ExercisePickerRow` currently HAS a trash button + confirmation dialog that calls `APIClient.deleteExercise(id:)` (global archive). **This is the "erroneous basket in the picker" the new task requires removing** — it globally archives an exercise from inside a selection picker, which is architecturally the wrong place for that action.
- `WorkoutDetailView.swift` → `ExerciseGroupCard` renders each exercise's sets for one workout inside a plain `ScrollView`/`VStack` (NOT a `List`) — there is currently no swipe gesture and no delete affordance of any kind here. Native `.swipeActions` only work inside `List` rows, so a custom drag-gesture swipe container will be needed to add swipe-to-delete without converting this screen to `List` (redesign risk).
- Backend (`coach/aghealth-backend`, lives inside the separate `openclaw-backup` workspace repo — see §2/§9) already has full exercise CRUD (`POST`/`GET`/`PATCH`/`DELETE(archive)` on `/api/v1/fitness/exercises`) and set-level operations scoped to a workout (`POST .../workouts/:workoutId/sets`, `DELETE .../workouts/:workoutId/sets/:id`). **There is no endpoint to remove all of one exercise's sets from one workout in a single call** — this is the "minimal correct endpoint" the task anticipates. Recommended shape: `DELETE /api/v1/fitness/workouts/:workoutId/exercises/:exerciseId` — deletes all `fitness_strength_sets` rows for that `(workout_id, exercise_id)` pair; 404 if the workout doesn't exist; 404 if nothing matched. No DB schema/migration change is needed — `fitness_strength_sets` already supports this query as-is.
- `aghealth-backend` runs live as systemd `aghealth-backend.service` (bound to `100.123.202.44:8791`). After backend code changes land, the service needs a restart to actually serve them.
- The Xcode project (`Fitness API.xcodeproj`) uses Xcode 16's `PBXFileSystemSynchronizedRootGroup` — a new `ExercisesView.swift` dropped into `Fitness API/UI/` is picked up automatically; no manual `project.pbxproj` edit is needed.
- Unrelated, pre-existing, NOT part of this task: the `openclaw-backup` workspace repo (where the backend source physically lives) currently has an **uncommitted, unused** `archive(id)` function added to `coach/aghealth-backend/src/repositories/workouts.js` (workout-level soft-delete; not called from any route or test). It predates this task and was intentionally left untouched.

Files changed (code): none this session.
Files changed (docs): `AGHealth_PROJECT_STATUS.md` (this checkpoint).

Backend endpoints:
- Existing, reused as-is: `POST/GET/PATCH/DELETE /api/v1/fitness/exercises[/:id]`, `POST /api/v1/fitness/workouts/:workoutId/sets`, `DELETE /api/v1/fitness/workouts/:workoutId/sets/:id`.
- To add: `DELETE /api/v1/fitness/workouts/:workoutId/exercises/:exerciseId` (not yet implemented).

Tests: none run this session (no code changed). Last known-good baseline: 42/42 backend tests passing as of commit `51a94ee` / the `82c9737` docs update.

Last safe commit:
- iOS repo (`aghealth-work`): `82c9737` — "Update AGHealth project status and roadmap" (in sync with `origin/main`).
- Backend/workspace repo (`openclaw-backup`): untouched by this task; it has a pre-existing, unrelated uncommitted `workouts.js` diff (see Findings) that is explicitly NOT part of this checkpoint and NOT to be committed as part of exercise management.

Next Action (for the next session, in order):
1. Backend: implement `DELETE /api/v1/fitness/workouts/:workoutId/exercises/:exerciseId` in `coach/aghealth-backend` (`removeByExercise` in `src/repositories/sets.js`, handler in `src/routes/workouts.js`, route registration in `src/server.js`); add tests; run `npm test`; restart `aghealth-backend.service`.
2. iOS: add `deleteWorkoutExercise(workoutId:exerciseId:)`, `createExercise(...)`, `patchExercise(...)` to `APIClient.swift`.
3. iOS: strip the trash button / `onDelete` / confirmation dialog out of `ExercisePickerView`/`ExercisePickerRow` in `StrengthWorkoutView.swift` (picker becomes selection-only); remove the now-dead `deleteExercise(_:)` helper in `StrengthWorkoutView`.
4. iOS: add swipe-to-delete on `ExerciseGroupCard` in `WorkoutDetailView.swift` (custom gesture, confirmation dialog, calls the new endpoint, refreshes the detail on success).
5. iOS: create `Fitness API/UI/ExercisesView.swift` (list/create/edit/archive-delete of the global catalog) and wire it into `MoreSectionView.swift` as "Упражнения".
6. Manually verify the 5 scenarios from the original task (delete-from-workout, re-add via picker, picker has no delete affordance, empty state, directory CRUD), then update `AGHealth_PROJECT_STATUS.md` for real (§4/§5/§7/§11), commit, push.

Do not:
- implement manual workout creation from scratch / `AGH-20`
- redesign existing UI, or convert `WorkoutDetailView`/`StrengthWorkoutView` to `List`-based screens beyond the minimum needed for the swipe gesture
- add unrelated functionality

### Architecture rule (must hold once this task ships)

- Deleting an exercise from one specific workout ≠ deleting/archiving the exercise globally. These are two different actions on two different endpoints.
- Global archive/delete (`DELETE /api/v1/fitness/exercises/:id`) lives ONLY in the new "Упражнения" directory screen (`ExercisesView.swift`).
- The exercise picker (`ExercisePickerView` in `StrengthWorkoutView.swift`) is selection-only — no delete/edit/archive affordance of any kind.
- Manual "create workout from scratch" (`AGH-20`) is explicitly out of scope for this task and must not be implemented as a side effect.

---

## 1. Project Overview

**AGHealth** is a personal, lifelong health-data platform for a single user (Анна). It is not a medical device and not a diagnostic tool — it's a personal archive + analytics + an AI interpreter on top of the user's own data.

End-to-end data flow:

```text
Apple Watch → Apple Health / HealthKit → AGHealth iOS → AGHealth Backend → AI Agent
```

- **Apple Watch / Apple Health** — the primary source of workout data (and, in the future, other health metrics).
- **AGHealth iOS** — the native SwiftUI app: reads HealthKit, lets the user enrich workouts (strength exercises/sets), and is the user-facing surface going forward.
- **AGHealth Backend** — a small Node.js + PostgreSQL API that is the source of truth for structured data.
- **AI Agent** — analyzes/interprets data on request; it does not store data and does not run deterministic calculations itself (that's Backend's job).

Fitness/workouts is the **first** domain built this way. The long-term product vision (documented in the `openclaw-backup` repository, not yet built here) is much broader: nutrition, sleep, menstrual cycle, medications, doctor visits, lab results, mood/wellbeing, body measurements, cosmetics, dental, pets, documents, notifications — see §6 Roadmap.

---

## 2. Repository Structure

- **`goryaynova/AGHealth`** — **this repository.** The current, separate, standalone iOS app repository. All iOS Swift code and this status file live here. This is the only repository iOS work should be pushed to.
- **`goryaynova/openclaw-backup`** — a **different, older, much larger repository**. It's the general workspace/auto-backup repo for the AI agent this project grew out of. It contains:
  - the original product architecture and planning documents (`coach/ARCHITECTURE_V0.1.md` and friends — see §6/§9 for exact files),
  - the AGHealth backend source code (`coach/aghealth-backend/`, Node.js + PostgreSQL, currently deployed as `aghealth-backend.service`),
  - an unrelated legacy Telegram bot project (`coach/coach-bot.js`, `health/health-bot.js`) that predates and is **separate from** AGHealth iOS.
- **They are not the same repository and must not be treated as one.** `openclaw-backup` (specifically its `coach/` folder) is used **only as a historical/architectural context source** for AGHealth. The current iOS product code is developed exclusively in `AGHealth`. Nothing from `openclaw-backup` should be copied wholesale into `AGHealth`, and this status file should not be duplicated back into `openclaw-backup`.
- **`openclaw-backup/coach`** specifically is a different, unrelated project scope (a personal Telegram AI-coach/health-bot workspace) — do not confuse it with AGHealth iOS work, even though the AGHealth backend code physically lives inside it for now (see Known Issues, §9).

---

## 3. Current Architecture

### Implemented

- **iOS:** SwiftUI app, Xcode project `Fitness API.xcodeproj` / `Fitness API.xcworkspace`. Networking via a plain `APIClient` (URLSession, no third-party dependencies observed). No local persistence layer yet — every screen fetches from the backend over the network each time.
- **HealthKit:** authorization request flow; reading real `HKWorkout` objects for the last 30 days on each manual sync.
- **Backend:** Node.js, **no HTTP framework** (`node:http`, manual routing) — `coach/aghealth-backend/` inside `openclaw-backup`, running as systemd service `aghealth-backend.service`.
- **Database:** PostgreSQL (`aghealth` DB), tables `fitness_exercises`, `fitness_workouts`, `fitness_strength_sets`, `events`. Legacy `coach-bot.db` (SQLite, Telegram bot) still exists separately and is **not** migrated or touched.
- **API:** REST-ish, CRUD-style endpoints under `/api/v1/fitness/*` plus `GET /api/v1/timeline` and `GET /health`. Full contract implemented for exercises/workouts/sets; see `coach/AGHEALTH_VERTICAL_SLICE_1_STRENGTH.md` in `openclaw-backup` for the detailed spec.
- **Authentication:** a single static Bearer token (`AGHEALTH_API_TOKEN`) shared by the whole app, checked on every `/api/v1/*` call. This is explicitly a **development-level** auth model (see Known Issues, §9), not a real per-user auth system.
- **AI Agent:** not integrated into the product at all yet. Right now "AI" only exists as this OpenClaw agent doing the diagnosis/build/documentation work described in this file, not as an in-app feature.

### Planned (documented, not built)

- Full HealthKit metrics beyond the current basics: HR time series, HRV, resting HR, sleep, VO2max, GPS route, cadence, power, swim laps (Phase 2 fields already reserved conceptually in `ARCHITECTURE_V0.1.md` §8, no DB columns exist for them yet except `distance_m`/`energy_burned_kcal`, which are implemented).
- Local iOS persistence / offline read (SwiftData vs Core Data — Open Decision #7, unresolved).
- Automatic/background HealthKit sync (observer queries) — today sync is a manual button tap only.
- A unified Notification Engine (local + APNs hybrid — architecture approved, not implemented; needs Apple Developer Program).
- A formal AI query/retrieval layer (architecture approved in `AGHEALTH_NOTIFICATIONS_AND_AI_PROPOSAL.md`, not implemented for any domain yet).
- PostgreSQL migration of the other, still-JSON-based `health-bot` domains (cycle, medications, labs, mood, cosmetics) — explicitly deferred, not started.
- Multi-domain backend refactor (framework choice, layering) — deferred until domain count grows (Open Decision #8).

**Do not treat anything in "Planned" as existing.** Where the old architecture docs in `openclaw-backup` describe a fuller system than what's actually running, the actual current code wins — see §9 for the specific gaps found.

---

## 4. Completed Work / History

In order, "what was done → result":

1. **Legacy Telegram AI-coach project (`coach-bot`, pre-pivot).** Built a Telegram-bot-based fitness/nutrition tracker (`@privatannabot`) with a SQLite backend (`coach-bot.db`: `workouts`, `exercise_catalog` with 33 real exercises, `strength_sets`, `nutrition_entries`, etc.) and a working `/sync` HTTP contract for HealthKit data (`FITNESS_API_CONTRACT.md`). → A fully working, still-running Telegram interface (Phase 1), later reused as historical/technical context, not as the product going forward.
2. **Product pivot to AGHealth (09.09.2026).** Full repo/backend audit; decided the product should be an iOS-first, backend-source-of-truth platform instead of a Telegram bot. → `ARCHITECTURE_V0.1.md` (26 sections) drafted and approved with 11 open decisions; PostgreSQL approved as the target unified database.
3. **Event/Timeline model proposal (10.09.2026).** → Approved: domain tables remain source of truth, a single `events` index table powers a future Timeline view.
4. **iOS Storage/Offline-Sync + Documents proposal (10.09.2026).** → Approved: local iOS mirror of structured data, two sync flows (HealthKit push, Domain Sync push+pull), PostgreSQL as sole canonical source of truth, client-generated IDs + idempotent upserts required everywhere.
5. **Notifications + AI architecture proposal (11.09.2026).** → Approved: hybrid local/APNs notifications (APNs not blocking MVP), hybrid AI layer (OpenClaw agent for now, retrieval/analytics stays in backend code, not in the LLM).
6. **Requirements → Backlog → MVP process (11.09.2026).** → Fitness domain fully specified: 36 requirements (`REQ-001`–`REQ-036`), 29 backlog items (`AGH-1`–`AGH-29`), an 18-item MVP scope, and a chosen first vertical slice: **end-to-end manual strength workout**.
7. **Backend Vertical Slice #1 implemented (11–13.09.2026).** New `aghealth-backend` (Node.js + PostgreSQL) built from scratch, separate from legacy `coach-bot.db`: `fitness_exercises`/`fitness_workouts`/`fitness_strength_sets`/`events` tables, full REST API, the 33 legacy exercises seeded, 42 automated backend tests. → A working, tested backend for strength workouts, independent of the Telegram bot's SQLite.
8. **Separate iOS GitHub repository created (`goryaynova/AGHealth`).** → A dedicated repo for the iOS app, decoupling it from the general `openclaw-backup` workspace.
9. **iOS: HealthKit authorization + real workout reading.** → App can request HealthKit permission and read actual `HKWorkout` records instead of hardcoded/demo data.
10. **iOS: manual sync (`SettingsView`).** → A button that pulls the last 30 days of HealthKit workouts and pushes each to the backend, using the HealthKit workout UUID as the backend workout ID (idempotent — safe to re-run).
11. **iOS: real Workout List + filters + Workout Detail.** → Replaced earlier hardcoded UUIDs with live API data; list supports filtering by workout type; detail screen shows real metrics and strength sets from the backend.
12. **iOS: add sets to an existing workout (`StrengthWorkoutView`) + Detail refresh.** → A user can add exercises/sets onto an already-synced workout and immediately see the updated detail.
13. **iOS + backend: exercise deletion/archive (13.09.2026, commit `51a94ee`).** → Trash button + confirmation dialog in the exercise picker, calling the existing backend `DELETE /api/v1/fitness/exercises/{id}` (soft-delete/archive); archived exercises disappear from the picker but historical sets keep working.
14. **Data cleanup: two erroneous test `running` workouts removed (13.09.2026, same commit).** → Diagnosed as leftover manual/curl test data from backend debugging (not a real sync bug, not real user workouts); removed from PostgreSQL (soft-deleted + hidden Timeline events + one orphan test set hard-deleted). 27 real workouts untouched, 42/42 backend tests still pass.
15. **Documentation: `AGHealth_PROJECT_STATUS.md` created (13.09.2026), then rewritten into this full operational status doc (13.09.2026, this update).** → A single, accurate, up-to-date reference file that doesn't require reading all of `openclaw-backup` to understand the project.

---

## 5. Current Implemented Features

Legend: **implemented** = works today · **partial** = exists but incomplete/limited · not listed = not implemented (see §6/§7 for planned work).

| Area | Status | Notes |
|---|---|---|
| iOS UI | **implemented** | SwiftUI, custom dark theme components, Home/Workouts/Settings sections |
| HealthKit permissions | **implemented** | Explicit authorization request flow |
| HealthKit workout reading | **partial** | Reads real `HKWorkout`s, but only the **last 30 days** on each sync — not the full lifelong history the requirements call for (see §9) |
| Workout sync (push to backend) | **partial** | Manual button only, no automatic/background sync (no observer queries); idempotent by HealthKit UUID; per-workout error handling so one failure doesn't abort the batch |
| Workout list + filters | **implemented** | Real API data, filter by workout type |
| Workout detail | **implemented** | Real metrics + strength sets from the backend, "no data" shown for missing optional metrics |
| Strength workouts — add sets to existing workout | **implemented** | Only works on an already-existing (HealthKit-synced) workout |
| Strength workouts — create a brand-new manual workout from scratch | **not implemented** | No UI path to create a workout that isn't already synced from HealthKit; backend supports `source: manual` creation, iOS doesn't expose it (see §7 P1) |
| Exercises — view/select | **partial** | Exists only as a picker embedded in the strength-add flow, not a standalone "My Exercises" screen. **Being replaced** by a dedicated `ExercisesView.swift` — see Current Task Checkpoint above |
| Exercises — create/edit | **not implemented** | Backend endpoints (`POST`/`PATCH /api/v1/fitness/exercises`) exist and work, iOS `APIClient` has no methods for them yet — planned as part of the in-progress task above |
| Exercises — delete/archive | **superseded, being reworked** | The confirmation dialog + trash button added 13.09.2026 lives *inside the exercise picker*, which conflates global archive with per-workout removal — this is being removed per the Current Task Checkpoint above. Do not treat this row as the current target design. |
| Backend / API | **implemented** | Node.js, no framework, REST endpoints for exercises/workouts/sets/timeline, Bearer auth, 42 automated tests passing |
| Database | **implemented** | PostgreSQL `aghealth` DB; legacy `coach-bot.db` (SQLite) still running independently, not migrated |
| Authentication | **partial** | Single shared static Bearer token — functional but development-grade only, no per-user auth |
| Timeline | **partial** | Backend creates `events` rows and exposes `GET /api/v1/timeline`; **no iOS UI consumes it yet** |
| Settings | **partial** | Manual sync trigger + one-line result message; no persisted sync history |
| Logging / error handling | **partial** | Structured `APIError` with localized messages; per-workout error isolation during sync; console `print()` logging only, nothing persisted client-side |

---

## 6. Roadmap

Carried over from `openclaw-backup` (`ARCHITECTURE_V0.1.md`, `BACKLOG.md`, `MVP_SCOPE.md`) and reconciled with what's actually built. This is **documentation only** — nothing below should be started without a separate, explicit task.

- **HealthKit / Apple Health:** full historical (not 30-day-windowed) import; automatic/background sync via observer queries; Phase 2 metrics (HR time series, HRV, resting HR, VO2max, GPS route, cadence, power).
- **Workout data:** sync status/history UI (`AGH-7`); tracking of *changed* HealthKit workouts, not just new ones (`AGH-5` refinement); dedup hardening (`AGH-6`, mostly done via idempotent UUID).
- **Strength training:** exercise create/edit in iOS (`AGH-10` remainder); standalone "My Workouts"/"My Exercises" screens (`AGH-8`/`AGH-9` full versions); manual "from scratch" workout creation (`AGH-20` full version); per-exercise progression (`AGH-13`); muscle-group balance analysis (`AGH-14`).
- **Running / Swimming / Cycling / Walking / Tennis:** specialized metrics + progression screens (`AGH-15`–`AGH-19`) — deferred by the approved MVP scope; generic list/detail already shows these workouts with basic HealthKit fields.
- **Health metrics (beyond fitness):** sleep, HRV, resting HR, VO2max, GPS/route, body measurements — not started as domains at all in AGHealth.
- **Synchronization:** Domain Sync (bidirectional, tombstones, LWW + recoverable buffer for conflicts) — architecture approved, not implemented; iOS offline-first local mirror — not implemented (no local persistence at all yet).
- **Backend:** multi-domain refactor when domain count grows (possible move to a lightweight framework, Open Decision #8); unify auth tokens across domains instead of per-domain static tokens.
- **Database:** migrate other `health-bot` JSON domains (cycle, medications, labs, mood, cosmetology) into PostgreSQL — explicitly deferred until each domain gets its own Requirements pass; at-rest encryption — not decided.
- **AI Agent / analytics:** Fitness Analytics engine (weekly/monthly summary `AGH-22`, training volume `AGH-23`); AI Q&A on fitness data (`AGH-25`–`AGH-28`) — depends on the approved-but-unbuilt AI retrieval/query layer.
- **Timeline:** iOS Timeline UI consuming the already-working backend `events`/`GET /api/v1/timeline` (`AGH-29` iOS side); cross-domain timeline once other domains exist.
- **Notifications/automation:** unified Notification Engine, local + APNs hybrid — architecture approved, needs Apple Developer Program ($99/year) before APNs can ship.
- **UI:** subjective workout fields — perceived difficulty / pain level / free-text comment (`AGH-21`); broader navigation/screen map (Home / Training / Nutrition / Measurements / Health / Cosmetics / Pets / Settings) is still an unfinalized draft in `ARCHITECTURE_V0.1.md` §22.
- **Infrastructure:** Apple Developer Program enrollment (needed for real-device distribution, TestFlight, APNs); iOS local persistence technology choice (SwiftData vs Core Data, Open Decision #7 — still unresolved); production-grade backups/retention for PostgreSQL (currently only the general git auto-backup covers it).
- **Other domains (documented in `openclaw-backup`, not started for AGHealth at all):** Nutrition, Menstrual cycle, Medications, Doctor visits, Lab/research results, Wellbeing/mood diary, Body measurements, Cosmetics, Dental, Favorite doctors, Pets, Documents-as-first-class-entity. These currently only exist as legacy JSON data inside the unrelated `health-bot` Telegram service.

---

## 7. Backlog / Next Tasks

**P0 — blocks further development:** none currently. The app and backend both work end-to-end for the manual-strength-workout slice; nothing is broken or blocking.

**P1 — next important functional step:**
- **Finish manual workout creation from scratch** (`AGH-20` full version) — today `StrengthWorkoutView` can only add sets to an *existing* HealthKit-synced workout; there's no UI to create a new workout (type/date/duration) that isn't tied to HealthKit. Backend already supports `source: "manual"` creation. Status: **partial**.
- **Add exercise create/edit to iOS** (`AGH-10` remainder) — backend `POST`/`PATCH /api/v1/fitness/exercises` already exist and are tested; iOS only has delete. Status: **partial**.
- **Fix the 30-day sync window** (`AGH-4`) — requirements call for a full lifelong historical import on first sync, current code hardcodes the last 30 days. Status: **partial**.
- **Standalone "My Exercises" / "My Workouts" screens** (`AGH-9`/`AGH-8`) — currently implicit (a picker + a filtered general list), not the dedicated views the requirements describe. Status: **partial**.

**P2 — subsequent features:**
- Strength progression per exercise (`AGH-13`). Dependency: `AGH-11` (done). Status: **planned**.
- Muscle-group balance analysis (`AGH-14`). Dependency: `AGH-12` (done). Status: **planned**.
- Weekly/monthly summary (`AGH-22`) and training volume (`AGH-23`) analytics. Status: **planned**.
- iOS Timeline UI (`AGH-29` iOS side) — backend already emits `events`/`GET /api/v1/timeline`. Status: **planned**.
- Sync status/history screen (`AGH-7`). Status: **planned**.
- Specialized Running/Swimming/Cycling/Walking/Tennis screens (`AGH-15`–`AGH-19`). Status: **planned**.
- Subjective workout fields — pain/difficulty/comment (`AGH-21`). Status: **planned**.

**P3 — long-term/optional:**
- AI Q&A on fitness data (`AGH-25`–`AGH-28`). Status: **blocked** — needs the AI retrieval/query layer from `AGHEALTH_NOTIFICATIONS_AND_AI_PROPOSAL.md` to be built first.
- Notification Engine (local + APNs hybrid). Status: **blocked** — needs Apple Developer Program enrollment.
- iOS local persistence / true offline support. Status: **blocked** — needs Open Decision #7 (SwiftData vs Core Data) resolved.
- PostgreSQL migration of other `health-bot` domains (cycle, medications, labs, mood, cosmetics). Status: **blocked** — each domain needs its own Requirements pass first (only Fitness has one so far).
- Any brand-new health domain (Sleep, Nutrition-in-AGHealth, Body Measurements, Documents, Pets, Dental, etc.). Status: **planned**, far future — no Requirements exist for these in AGHealth yet.
- Production security hardening: per-user auth model, at-rest encryption, real DB backup/retention policy. Status: **planned**.

---

## 8. Current Focus

The originally-scoped **Vertical Slice #1 (manual strength workout, end-to-end)** is backend-complete but has two iOS gaps that make it not fully deliverable as designed: no "create workout from scratch" and no exercise create/edit on iOS. The recommended next functional block is:

**Recommended: close the Vertical Slice #1 gaps first** — implement manual "create new workout" (P1) and exercise create/edit on iOS (P1). Both reuse existing, already-tested backend endpoints, so this is the smallest remaining gap and finishes what was already promised for this slice.

If a different order is preferred, the equally-valid next candidates, in a reasonable sequence, are:
1. Fix the 30-day HealthKit sync window → full historical import (`AGH-4`).
2. Build the iOS Timeline screen (`AGH-29`) — the backend side is already done and unused.
3. Fitness Analytics (`AGH-22`/`AGH-23`/`AGH-13`/`AGH-14`) — most valuable once more workout history has accumulated.

---

## 9. Known Issues / Technical Debt

- **30-day sync window contradicts the approved requirement** (`AGH-4`/REQ-007: full lifelong import) — `SettingsView.startManualSync()` hardcodes the last 30 days.
- **No automatic/background HealthKit sync** — the user must open Settings and tap manually every time (`AGH-5` partial).
- **No offline/local persistence on iOS at all** — every screen re-fetches over the network; this contradicts the long-term architecture principle that iOS should support offline read from a local cache (`AGHEALTH_IOS_SYNC_AND_DOCUMENTS_PROPOSAL.md`).
- **Single shared static Bearer token** (`AGHEALTH_API_TOKEN`) for all API calls — explicitly a development-only auth model (`ARCHITECTURE_V0.1.md` §17), not production-grade.
- **No at-rest encryption** on PostgreSQL or on any future document storage.
- **Backend has no HTTP framework** — bare `node:http` with manual routing; fine for one domain, flagged in `ARCHITECTURE_V0.1.md` Open Decision #8 as needing revisit once more domains are added.
- **iOS local storage technology unresolved** (SwiftData vs Core Data, Open Decision #7) — currently moot since there's no local storage yet, but blocks any offline-support work.
- **Legacy `coach-bot` (SQLite, Telegram `@privatannabot`) is still active and independently writable** — a second, unsynced source of truth for the same Strength domain during the transition period. This is an explicitly accepted temporary state (`ARCHITECTURE_V0.1.md` §23/24), but real divergence risk exists if both are used for real data entry at the same time.
- **Backup strategy is just the general workspace git auto-backup** (`openclaw-backup`) — not a real database backup/retention policy (`ARCHITECTURE_V0.1.md` §19 flags this as a pre-production gap).
- **Console `print()`-based logging only** on iOS — nothing persisted client-side, no crash reporting.
- **Two local clones of the AGHealth iOS repo exist on the dev server** (`/root/.openclaw/workspace/aghealth-work` — canonical, tracks `origin/main` — and a stale `/tmp/AGHealth` with an old unpushed commit). Not cleaned up automatically; flagged here so a future agent doesn't get confused about which is current.
- **AGHealth backend code physically lives inside the unrelated `openclaw-backup/coach/aghealth-backend` folder**, not inside the `AGHealth` iOS repo — this is a pre-existing arrangement, not something introduced by this task, but worth knowing when looking for backend source.
- **Documentation gap (now fixed by this task):** the previous version of this file only covered the most recent block (exercise deletion + data cleanup) and had no history, architecture summary, or roadmap — a future agent would have had to read all of `openclaw-backup` to get context. Resolved by this rewrite.

---

## 10. Agent Workflow / Checkpoint Rules

These are **permanent project rules**, not a description of any one current task. They exist so that after a crash, a finished session, or a session handover, the next coding agent can determine the exact current state and continue the work without re-analyzing the whole project.

### 10.0 Baseline rules (always apply)

1. Before starting any new task, always read `AGHealth_PROJECT_STATUS.md` first.
2. When more architectural/historical context is needed, consult `openclaw-backup` (mainly `coach/ARCHITECTURE_V0.1.md`, `coach/BACKLOG.md`, `coach/MVP_SCOPE.md`, `coach/requirements/fitness.md`, and the other `coach/AGHEALTH_*` proposal docs) as the source.
3. Do not change the existing UI or redesign it without an explicit requirement to do so.
4. When adding a feature, change only what's necessary.
5. Do not implement features that exist only in the roadmap without a separate, explicit task for them.
6. After finishing every functional block, update `AGHealth_PROJECT_STATUS.md`.
7. The status update must reflect: what was done, what changed, what now works, what remains, the next block, and any new known issues.
8. After finishing a functional block, commit and push to `origin/main`.
9. Do not mix AGHealth with `openclaw-backup/coach` — they are different projects.
10. Do not delete or rewrite the historical documentation in `openclaw-backup` for AGHealth's sake.

### 10.1 Checkpoint rules (how to survive crashes and session handovers)

**Rule 1 — The status file is the source of the current state.**
Before starting any substantial task the agent MUST:
- read `AGHealth_PROJECT_STATUS.md`;
- run `git status`;
- check the current branch;
- look at the last commits (`git log --oneline`);
- determine whether there are uncommitted changes;
- check the `Current Task Checkpoint` section, if it exists.
Do not start work "from a clean slate" if a checkpoint already exists in the project.

**Rule 2 — Large tasks are executed in phases.**
Do not shred work into micro-tasks just for agent resilience. Instead, split a large functional block into a few logically complete phases — for example: backend; iOS; a separate UI/integration piece; testing. A phase must be large enough to represent a finished, self-contained functional chunk.

**Rule 3 — After finishing a meaningful phase, create a checkpoint.**
After completing each logically complete phase the agent must:
- review the code;
- run the tests that belong to that phase;
- check `git diff`;
- update `AGHealth_PROJECT_STATUS.md`;
- update the `Current Task Checkpoint`;
- state the next phase / Next Action;
- make a commit.
If the phase is finished and a commit is safe, the checkpoint must reference that commit.

**Rule 4 — Do not commit broken code just to create a checkpoint.**
A checkpoint does not mean any intermediate code must be committed immediately. If the current implementation is unfinished and potentially broken:
- do not make a fake commit;
- record the state in the documentation;
- describe exactly what is IN PROGRESS;
- state a concrete Next Action.
If there is a logically complete part, it can and should be saved as its own commit.

**Rule 5 — The checkpoint must contain the actual state.**
Do not write `Backend — DONE` just because backend was planned. Status must reflect the actual code. For each phase use one of: `DONE`, `IN PROGRESS`, `NOT STARTED`, and where applicable `BLOCKED`.

**Rule 6 — The next session must be able to continue the work.**
The `Current Task Checkpoint` must let a new agent, without access to the previous session, understand: what was being worked on; what is already done; what is not done; which files were changed; which APIs were added/changed; which tests passed; the last safe commit; and what to do next. The Next Action must be concrete — not "continue the work", but e.g. "implement swipe-to-delete in `StrengthWorkoutView.swift` using existing endpoint X, then verify scenarios A–C".

**Rule 7 — Recovery after a crash.**
If a new session starts after the previous one crashed/was interrupted:
- do not start the implementation over;
- read the status/checkpoint;
- check git;
- determine the last safe commit;
- check for uncommitted changes;
- determine the last completed phase;
- continue from the Next Action.
If the actual code state diverges from the checkpoint, update the checkpoint first, then continue the implementation.

**Rule 8 — Push after a safe checkpoint.**
After a meaningful completed phase and its corresponding commit, the agent must push to `origin/main` if the task is meant to be done through the shared repository. This is required so the work can be recovered in a new session.

**Rule 9 — Do not rewrite the checkpoint retroactively without cause.**
Do not rewrite the history of already-completed phases without a reason. If an error is found in a previous phase: explicitly flag it; state exactly what is being fixed; update the current phase; and keep a clear change history via git.

**Rule 10 — Do not expand the task because of the checkpoint.**
A checkpoint is not a reason to implement extra features. The agent must continue only the current task and its explicitly necessary dependencies.

### 10.2 Standard `Current Task Checkpoint` format

The `Current Task Checkpoint` section (kept near the top of this file) is the live checkpoint. Its exact wording may be adapted to fit the document, but the required fields below must be preserved:

```text
## Current Task Checkpoint

Task:
<name of the functional block>

Phase:
<current phase>

Status:
DONE / IN PROGRESS / NOT STARTED / BLOCKED

Completed:
- ...

In progress:
- ...

Not started:
- ...

Files changed:
- ...

API / backend changes:
- ...

Tests:
- ...

Last safe commit:
- <commit hash>

Next Action:
- <concrete next action>

Do not:
- <important constraints of the current task>
```

**`AGHealth_PROJECT_STATUS.md` is the short operational source of truth for AGHealth's current state. Git history and the original documentation are used to recover details, but this status file must stay accurate and current.**

---

## 11. Last Completed Block

**Commit `51a94ee` — "Add exercise deletion and clean invalid workouts"** (2026-09-13, pushed to `origin/main`).

- Added exercise deletion to iOS: trash button + confirmation dialog in the exercise picker (`ExercisePickerView`/`ExercisePickerRow` in `StrengthWorkoutView.swift`), calling the already-existing `APIClient.deleteExercise(id:)` → backend `DELETE /api/v1/fitness/exercises/{id}` (soft-delete/archive). The exercise is only removed from the local list after a confirmed 2xx response; on failure it stays and an inline error is shown.
- Diagnosed and cleaned up two erroneous test `running` workouts found in the backend (`7690a8f4-…` source=manual, `368bf4a0-…` source=healthkit, both dated 2026-09-13 with a round 09:30:00 start and exactly 1800s duration, no distance/energy) — confirmed as leftover manual/curl test data from backend debugging, not a real sync bug and not real user data (`SettingsView` always sends `source: "healthkit"`, so the `manual`-sourced row could never come from the app). Soft-deleted both workouts, hid the two matching Timeline events, and removed one orphan test strength-set row. 27 real workouts were left untouched.
- Verified backend: 42/42 automated tests still pass, no code changes needed in the sync chain (root cause was bad test data, not a bug).
- Pushed to `origin/main` (`a2f3e36` → `51a94ee`).
