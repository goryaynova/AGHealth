# AGHealth — Project Status

**Repository:** `goryaynova/AGHealth` — this is a **separate, standalone GitHub repository** for the AGHealth iOS app.

> ⚠️ `openclaw-backup/coach` is a **different project** (a personal AI-coach/monitoring workspace) and is **not** the AGHealth iOS repository. Do not confuse the two.

Last updated: 2026-09-13.

---

## Goal

```text
Apple Watch
  → Apple Health (HealthKit)
  → AGHealth iOS app
  → AGHealth backend (PostgreSQL API)
  → AI Agent (future)
```

The app reads real workout data recorded by an Apple Watch from HealthKit, lets the
user enrich it with strength-training detail (exercises/sets), and syncs everything
to a backend so an AI agent can eventually reason over the full training history.

---

## Already implemented

### iOS (SwiftUI, `Fitness API/` target)

- HealthKit authorization request flow.
- Reading real workouts from HealthKit (`HealthKitSyncService`).
- Manual sync button (`SettingsView`) — pulls the last 30 days of HealthKit
  workouts and pushes each one to the backend; per-workout error handling so
  one failed upload doesn't abort the whole sync.
- Backend sync via `APIClient` — HealthKit workouts are always sent with
  `source: "healthkit"` and use the **HealthKit workout UUID as the backend
  workout ID** (idempotent — re-syncing never creates duplicates).
- Real workout list (`WorkoutsSectionView`) backed by `GET /api/v1/fitness/workouts`.
- Filters by workout type (Все/Силовые/Бег/Плавание/Велосипед).
- Workout Detail screen (`WorkoutDetailView`) backed by
  `GET /api/v1/fitness/workouts/:id`, showing HealthKit metrics (distance,
  energy burned) and any strength sets.
- Exercises/sets display grouped by exercise inside Workout Detail.
- Adding strength sets to an **existing** workout (`StrengthWorkoutView` +
  `APIClient.addStrengthSet`) — never creates a second workout.
- Workout Detail refresh after a set is added.
- **Exercise catalog management:**
  - Exercise picker (`ExercisePickerView`) used when adding an exercise to a
    strength workout, backed by `GET /api/v1/fitness/exercises`.
  - **Exercise deletion** — a trash button on each row in the exercise picker,
    with a confirmation dialog (`Удалить «<name>»?`). Confirming calls
    `APIClient.deleteExercise(id:)` (`DELETE /api/v1/fitness/exercises/{id}`).
    - Only removes the exercise from the local list **after** the backend
      call succeeds (200/2xx). If the backend call fails, the exercise stays
      in the list and the error message is shown inline.
    - Deleted (archived) exercises disappear from the exercise
      picker/selector immediately; the app filters out any exercise whose
      `archivedAt` is set.
    - No exercise **editing** was added — deletion only, per requirements.
    - Historical workouts and their sets are unaffected: the backend
      soft-deletes exercises (`archived_at` timestamp) rather than removing
      the row, so old sets that reference an archived exercise keep
      rendering correctly in Workout Detail.

### Backend (`coach/aghealth-backend/`, Node.js + PostgreSQL, separate host process)

- `fitness_workouts` — HealthKit + manual workouts, soft-delete via
  `deleted_at`.
- `fitness_exercises` — exercise catalog, soft-delete via `archived_at`.
- `fitness_strength_sets` — sets tied to a workout + exercise.
- REST API:
  - `POST /api/v1/fitness/workouts` (idempotent by client-supplied id)
  - `GET /api/v1/fitness/workouts` (list + filter by type/period, cursor pagination)
  - `GET /api/v1/fitness/workouts/:id` (detail incl. sets)
  - `PATCH /api/v1/fitness/workouts/:id`
  - `POST /api/v1/fitness/workouts/:workoutId/sets`
  - `DELETE /api/v1/fitness/workouts/:workoutId/sets/:id`
  - `GET /api/v1/fitness/exercises`
  - `DELETE /api/v1/fitness/exercises/:id` (archives, soft-delete)
- 42/42 automated backend tests passing (`npm test` in `coach/aghealth-backend`).

---

## Data cleanup log

**2026-09-13 — two invalid `running` workouts removed from the backend.**

| Field | Workout 1 | Workout 2 |
|---|---|---|
| ID | `7690a8f4-d8d7-4422-b410-6dd6acf58747` | `368bf4a0-fa8d-4cc8-ae63-3e9a915b3fc5` |
| `workout_type` | running | running |
| `source` | **manual** | healthkit |
| `started_at` | 2026-09-13 09:30:00+03 | 2026-09-13 09:30:00+03 |
| `duration_sec` | 1800 (exactly 30:00) | 1800 (exactly 30:00) |
| `distance_m` / `energy_burned_kcal` | both NULL | both NULL |
| `created_at` | 2026-09-13 10:22:20+03 | 2026-09-13 10:23:36+03 |

**Why they were wrong:**
- The iOS app's only workout-creation call site (`SettingsView.startManualSync()`)
  always sends `source: "healthkit"` — it can **never** produce a `source: "manual"`
  workout. So the manual-source row could not have come from the app's sync flow.
- Both rows share suspiciously round values that never occur in real Watch data:
  an exact `09:30:00` start time and an exact `1800`-second duration, with no
  distance/energy at all (every genuine HealthKit `running` row has non-round
  second-level timestamps and populated distance/energy).
- The manual-source row had a linked `fitness_strength_sets` row with the
  hardcoded id `00000000-0000-0000-0000-000000000002` — not something the iOS
  app or any real client generates (it always uses `UUID().uuidString`). This
  is a clear fixture/test artifact.
- Both rows were created ~1 minute apart, straddling a backend service
  restart at 10:23 that day, consistent with manual `curl`/smoke testing of
  the workout API during backend/API debugging earlier the same day — not
  with real device sync (there is only ever one sync per manual-sync tap, and
  it never produces a `manual`-sourced workout).

**Source of the bad data:** manual/test API calls made directly against the
backend during development/debugging, **not** a bug in `SettingsView` →
`HealthKitSyncService` → `APIClient.createWorkout` → backend. That chain was
inspected end-to-end and is correct: `source` is hardcoded to `"healthkit"`
for every real sync, and the create endpoint is idempotent by client-supplied
id, so a normal re-sync cannot recreate these rows.

**What was done:**
- Soft-deleted both `fitness_workouts` rows (`deleted_at = now()`), using the
  exact same mechanism as the existing (unrouted) `workoutsRepo.archive()`
  helper — consistent with how the app already soft-deletes exercises.
- Hid the two matching `events` timeline rows (`hidden_at = now()`) so no
  stale "Тренировка (running) — 30 мин" entries linger in any future
  timeline feature.
- Deleted the orphaned test `fitness_strength_sets` row
  (`00000000-0000-0000-0000-000000000002`) attached to the manual workout.
- Real user workouts (27 remaining rows, all `source: healthkit`, all with
  plausible non-round timestamps and populated distance/energy where
  applicable) were **not** touched.
- **No code changes were made to the sync chain** — the root cause was bad
  test data, not a bug, so per the task's own instruction nothing extra was
  changed there.
- Verified with `npm test` in `coach/aghealth-backend`: 42/42 tests still pass.

---

## Roadmap (documentation only — nothing below is implemented yet)

- Sync history / sync logs (a visible record of past sync runs).
- Retry / structured error handling for failed per-workout uploads.
- Heart-rate time series.
- HRV (heart rate variability).
- Resting heart rate.
- Sleep data.
- VO2max.
- GPS route data.
- Cadence.
- Power (cycling).
- Swimming lap data.
- Other HealthKit metrics not yet ingested.
- Training analytics / trends.
- Integration with the AI Agent (recommendations, coaching insights).

None of the above should be started without a separate, explicit task — this
section exists purely to track what's intentionally deferred.
