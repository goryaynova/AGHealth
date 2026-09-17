import Foundation

final class APIClient {
    private let baseURL: URL
    private let token: String

    init(baseURL: URL, token: String) {
        self.baseURL = baseURL
        self.token = token
    }

    // MARK: - Health

    func healthCheck() async throws -> Bool {
        let url = baseURL.appendingPathComponent("health")

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        setAuthorizationHeader(on: &request)

        do {
            let (data, response) = try await URLSession.shared.data(
                for: request
            )

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            guard httpResponse.statusCode == 200 else {
                throw APIError.httpStatus(httpResponse.statusCode)
            }

            struct HealthResponse: Decodable {
                let status: String
            }

            let result = try JSONDecoder().decode(
                HealthResponse.self,
                from: data
            )

            return result.status == "ok"

        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.network(error.localizedDescription)
        }
    }

    // MARK: - Exercises

    /// One muscle worked by an exercise, with its role and relative weight.
    /// Matches backend `fitness_exercise_muscles` rows.
    struct ExerciseMuscle: Codable, Hashable, Identifiable {
        let groupKey: String        // canonical body part key
        let muscle: String?         // specific muscle (nullable)
        let role: String            // "primary" | "secondary"
        let contribution: Double     // 0..1
        let bodyRegion: String?

        var id: String { "\(groupKey)|\(muscle ?? "")|\(role)" }
        var isPrimary: Bool { role == "primary" }
    }

    struct Exercise: Identifiable, Codable, Hashable {
        let id: String
        let name: String
        let muscleGroup: String?
        // Structured muscle classification (v2 catalog). Optional so legacy/archived
        // rows and older backends still decode.
        let muscleGroupKey: String?
        let muscle: String?
        let equipment: String?
        let bodyRegion: String?
        let legacyKey: String?
        let archivedAt: String?
        // Full primary/secondary muscle mapping (single source of truth). Optional so older
        // backends without the mapping still decode.
        let muscles: [ExerciseMuscle]?

        var isArchived: Bool {
            archivedAt != nil
        }

        var primaryMuscle: ExerciseMuscle? {
            muscles?.first { $0.isPrimary } ?? muscles?.first
        }

        var secondaryMuscles: [ExerciseMuscle] {
            muscles?.filter { !$0.isPrimary } ?? []
        }
    }

    /// One muscle in a create/edit request. `bodyPart` may be a canonical key or a human label;
    /// `contribution` is optional (backend defaults it by role).
    struct MuscleInput: Encodable {
        let bodyPart: String
        let muscle: String?
        let contribution: Double?
    }

    func fetchExercises() async throws -> [Exercise] {
        let url = baseURL
            .appendingPathComponent("api/v1/fitness/exercises")

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        setAuthorizationHeader(on: &request)

        do {
            let (data, response) = try await URLSession.shared.data(
                for: request
            )

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            guard httpResponse.statusCode == 200 else {
                throw APIError.httpStatus(httpResponse.statusCode)
            }

            if let rawResponse = String(
                data: data,
                encoding: .utf8
            ) {
                print("AGHealth exercises response:")
                print(rawResponse)
            }

            struct ExercisesResponse: Decodable {
                let exercises: [Exercise]
            }

            let result = try JSONDecoder().decode(
                ExercisesResponse.self,
                from: data
            )

            print(
                "AGHealth exercises decoded count: \(result.exercises.count)"
            )

            return result.exercises

        } catch let error as APIError {
            throw error
        } catch {
            print("AGHealth exercises decoding/network error:")
            print(error)

            throw APIError.network(error.localizedDescription)
        }
    }

    /// Archives (soft-deletes) an exercise on the backend.
    ///
    /// Backend endpoint: `DELETE /api/v1/fitness/exercises/{id}`.
    /// This is a soft delete (`archived_at` is set) — existing strength sets
    /// that already reference this exercise keep working; the exercise just
    /// stops appearing in the default (non-archived) exercise list and can
    /// no longer be used for new sets.
    func deleteExercise(id: String) async throws {
        let url = baseURL
            .appendingPathComponent("api/v1/fitness/exercises/\(id)")

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        setAuthorizationHeader(on: &request)

        do {
            let (data, response) = try await URLSession.shared.data(
                for: request
            )

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                let responseBody = String(
                    data: data,
                    encoding: .utf8
                ) ?? "<empty response body>"

                print(
                    "AGHealth DELETE EXERCISE HTTP \(httpResponse.statusCode)"
                )
                print("AGHealth DELETE EXERCISE RESPONSE:")
                print(responseBody)

                throw APIError.httpStatus(httpResponse.statusCode)
            }

            print(
                "AGHealth DELETE EXERCISE SUCCESS HTTP \(httpResponse.statusCode)"
            )

        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.network(error.localizedDescription)
        }
    }

    /// Creates a new global exercise in the catalog.
    ///
    /// Backend endpoint: `POST /api/v1/fitness/exercises`.
    /// Used by the standalone «Упражнения» directory screen only.
    @discardableResult
    func createExercise(
        id: String,
        name: String,
        muscleGroup: String?
    ) async throws -> Exercise {
        // Legacy convenience: a single primary body part, no specific muscle.
        try await createExercise(
            id: id,
            name: name,
            primary: muscleGroup.map { MuscleInput(bodyPart: $0, muscle: nil, contribution: nil) },
            secondary: []
        )
    }

    /// Creates a global exercise with the structured primary/secondary muscle model.
    /// `POST /api/v1/fitness/exercises`.
    @discardableResult
    func createExercise(
        id: String,
        name: String,
        primary: MuscleInput?,
        secondary: [MuscleInput]
    ) async throws -> Exercise {
        let url = baseURL
            .appendingPathComponent("api/v1/fitness/exercises")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        setAuthorizationHeader(on: &request)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        struct CreateExerciseRequest: Encodable {
            let id: String
            let name: String
            let primary: MuscleInput?
            let secondary: [MuscleInput]
        }

        request.httpBody = try JSONEncoder().encode(
            CreateExerciseRequest(id: id, name: name, primary: primary, secondary: secondary)
        )

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                throw APIError.httpStatus(httpResponse.statusCode)
            }

            struct ExerciseResponse: Decodable {
                let exercise: Exercise
            }

            return try JSONDecoder().decode(ExerciseResponse.self, from: data).exercise

        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.network(error.localizedDescription)
        }
    }

    /// Edits an existing global exercise (name and/or muscle group).
    ///
    /// Backend endpoint: `PATCH /api/v1/fitness/exercises/{id}`.
    /// Used by the standalone «Упражнения» directory screen only.
    @discardableResult
    func patchExercise(
        id: String,
        name: String?,
        muscleGroup: String?
    ) async throws -> Exercise {
        try await patchExercise(
            id: id,
            name: name,
            primary: muscleGroup.map { MuscleInput(bodyPart: $0, muscle: nil, contribution: nil) },
            secondary: nil
        )
    }

    /// Edits a global exercise with the structured primary/secondary muscle model.
    /// `PATCH /api/v1/fitness/exercises/{id}`. When `primary` is provided the whole muscle
    /// mapping is rebuilt; pass `secondary` (possibly empty) alongside it.
    @discardableResult
    func patchExercise(
        id: String,
        name: String?,
        primary: MuscleInput?,
        secondary: [MuscleInput]?
    ) async throws -> Exercise {
        let url = baseURL
            .appendingPathComponent("api/v1/fitness/exercises/\(id)")

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        setAuthorizationHeader(on: &request)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        struct PatchExerciseRequest: Encodable {
            let name: String?
            let primary: MuscleInput?
            let secondary: [MuscleInput]?
        }

        request.httpBody = try JSONEncoder().encode(
            PatchExerciseRequest(name: name, primary: primary, secondary: secondary)
        )

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                throw APIError.httpStatus(httpResponse.statusCode)
            }

            struct ExerciseResponse: Decodable {
                let exercise: Exercise
            }

            return try JSONDecoder().decode(ExerciseResponse.self, from: data).exercise

        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.network(error.localizedDescription)
        }
    }

    /// Removes ONE exercise from ONE specific workout.
    ///
    /// Backend endpoint: `DELETE /api/v1/fitness/workouts/{workoutId}/exercises/{exerciseId}`.
    /// Deletes only that exercise's sets in this workout. The global exercise
    /// record and every other workout stay untouched. This is deliberately NOT
    /// the same as `deleteExercise(id:)` (which archives the exercise globally).
    func deleteWorkoutExercise(workoutId: String, exerciseId: String) async throws {
        let url = baseURL
            .appendingPathComponent(
                "api/v1/fitness/workouts/\(workoutId)/exercises/\(exerciseId)"
            )

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        setAuthorizationHeader(on: &request)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                let responseBody = String(data: data, encoding: .utf8) ?? "<empty response body>"
                print("AGHealth DELETE WORKOUT EXERCISE HTTP \(httpResponse.statusCode)")
                print(responseBody)
                throw APIError.httpStatus(httpResponse.statusCode)
            }

            print("AGHealth DELETE WORKOUT EXERCISE SUCCESS HTTP \(httpResponse.statusCode)")

        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.network(error.localizedDescription)
        }
    }

    // MARK: - Muscle Summary (weekly worked muscles)

    /// One muscle group's weekly training load, as returned by
    /// `GET /api/v1/fitness/muscle-summary`.
    /// One specific muscle inside a group, with its own load level.
    struct MuscleLoad: Codable, Hashable, Identifiable {
        let muscle: String
        let setEquivalents: Double
        let level: String
        let levelRu: String

        var id: String { muscle }
    }

    struct MuscleGroupLoad: Identifiable, Codable, Hashable {
        let groupKey: String
        let label: String
        let setEquivalents: Double
        let level: String     // "high" | "medium" | "low" | "none"
        let levelRu: String
        // Per-muscle breakdown inside this body part (for the expandable weekly categories).
        // Optional so older backends still decode.
        let muscles: [MuscleLoad]?

        var id: String { groupKey }
    }

    struct MuscleSummary: Codable {
        struct Totals: Codable, Hashable {
            let strengthSets: Int
            let strengthVolume: Int?
            let cardioWorkouts: Int
            let workedGroups: Int
        }
        let windowStart: String
        let windowEnd: String
        let days: Int
        let totals: Totals
        let groups: [MuscleGroupLoad]
    }

    /// Fetches the weekly worked-muscles summary powering the summary block and
    /// the body muscle map. Aggregates real completed workouts on the backend
    /// (strength sets + a fixed cardio mapping) — nothing is computed client-side.
    func fetchMuscleSummary(days: Int = 7) async throws -> MuscleSummary {
        var url = baseURL
            .appendingPathComponent("api/v1/fitness/muscle-summary")
        url.append(queryItems: [URLQueryItem(name: "days", value: "\(days)")])

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        setAuthorizationHeader(on: &request)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            guard httpResponse.statusCode == 200 else {
                throw APIError.httpStatus(httpResponse.statusCode)
            }

            return try JSONDecoder().decode(MuscleSummary.self, from: data)

        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.network(error.localizedDescription)
        }
    }

    // MARK: - Progression (weight over time, per exercise)

    struct ProgressionExercise: Identifiable, Codable, Hashable {
        let id: String
        let name: String
        let muscleGroup: String?
        let muscleGroupKey: String?
        let sessions: Int
        let lastPerformed: String?
        // Current top working weight and its change vs the previous session (CP5). Optional so older
        // backends still decode.
        let currentWeightKg: Double?
        let changeKg: Double?
    }

    struct ProgressionPoint: Identifiable, Codable, Hashable {
        let workoutId: String
        let date: String
        let topWeightKg: Double?
        let topReps: Int?
        let volume: Int
        let sets: Int

        var id: String { workoutId }
    }

    struct ExerciseProgression: Codable {
        struct ExerciseInfo: Codable {
            let id: String
            let name: String
            let muscleGroup: String?
            let muscleGroupKey: String?
            let muscles: [ExerciseMuscle]?
        }
        let exercise: ExerciseInfo
        let metric: String
        let points: [ProgressionPoint]
    }

    /// Exercises that have strength history (recent first), for the progression picker.
    func fetchProgressionExercises() async throws -> [ProgressionExercise] {
        let url = baseURL.appendingPathComponent("api/v1/fitness/progression")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        setAuthorizationHeader(on: &request)
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
            guard http.statusCode == 200 else { throw APIError.httpStatus(http.statusCode) }
            struct Wrapper: Decodable { let exercises: [ProgressionExercise] }
            return try JSONDecoder().decode(Wrapper.self, from: data).exercises
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.network(error.localizedDescription)
        }
    }

    /// Weight progression series for one exercise (never mixed with others).
    func fetchExerciseProgression(exerciseId: String, days: Int? = nil) async throws -> ExerciseProgression {
        var url = baseURL.appendingPathComponent("api/v1/fitness/exercises/\(exerciseId)/progression")
        if let days { url.append(queryItems: [URLQueryItem(name: "days", value: "\(days)")]) }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        setAuthorizationHeader(on: &request)
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
            guard http.statusCode == 200 else { throw APIError.httpStatus(http.statusCode) }
            return try JSONDecoder().decode(ExerciseProgression.self, from: data)
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.network(error.localizedDescription)
        }
    }

    // MARK: - Workouts

    // MARK: - Swimming progress

    struct SwimmingProgress: Codable {
        struct StyleTotal: Codable, Hashable, Identifiable {
            let style: String
            let label: String
            let distanceM: Double
            let durationSec: Double
            var id: String { style }
        }
        struct Week: Codable, Hashable, Identifiable {
            let week: String
            let weekStart: String
            let totalDistanceM: Double
            let totalDurationSec: Double
            var id: String { week }
        }
        struct Totals: Codable, Hashable {
            let distanceM: Double
            let durationSec: Double
        }
        let weeks: [Week]
        let styleTotals: [StyleTotal]
        let totals: Totals
    }

    func fetchSwimmingProgress(weeks: Int = 12) async throws -> SwimmingProgress {
        var url = baseURL.appendingPathComponent("api/v1/fitness/swimming/progress")
        url.append(queryItems: [URLQueryItem(name: "weeks", value: "\(weeks)")])
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        setAuthorizationHeader(on: &request)
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
            guard http.statusCode == 200 else { throw APIError.httpStatus(http.statusCode) }
            return try JSONDecoder().decode(SwimmingProgress.self, from: data)
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.network(error.localizedDescription)
        }
    }

    /// One swimming style segment sent to the backend on sync.
    struct SwimmingSegmentInput: Encodable {
        let style: String
        let distanceM: Double?
        let durationSec: Double?
    }

    func createWorkout(
        id: String,
        workoutType: String,
        startedAt: Date,
        durationSec: Int,
        source: String,
        distance: Double?,
        energyBurned: Double?,
        swimmingSegments: [SwimmingSegmentInput]? = nil
    ) async throws {

        let url = baseURL
            .appendingPathComponent("api/v1/fitness/workouts")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        setAuthorizationHeader(on: &request)

        request.setValue(
            "application/json",
            forHTTPHeaderField: "Content-Type"
        )

        struct CreateWorkoutRequest: Encodable {
            let id: String
            let workoutType: String
            let startedAt: Date
            let durationSec: Int
            let source: String
            let distance: Double?
            let energyBurned: Double?
            let swimmingSegments: [SwimmingSegmentInput]?
        }

        let body = CreateWorkoutRequest(
            id: id,
            workoutType: workoutType,
            startedAt: startedAt,
            durationSec: durationSec,
            source: source,
            distance: distance,
            energyBurned: energyBurned,
            swimmingSegments: swimmingSegments
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        request.httpBody = try encoder.encode(body)

        print("AGHealth CREATE WORKOUT")
        print("AGHealth workout id: \(id)")
        print("AGHealth workout type: \(workoutType)")
        print("AGHealth workout source: \(source)")

        do {
            let (data, response) = try await URLSession.shared.data(
                for: request
            )

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                let responseBody = String(
                    data: data,
                    encoding: .utf8
                ) ?? "<empty response body>"

                print(
                    "AGHealth CREATE WORKOUT HTTP \(httpResponse.statusCode)"
                )
                print("AGHealth CREATE WORKOUT RESPONSE:")
                print(responseBody)

                throw APIError.httpStatus(httpResponse.statusCode)
            }

            print(
                "AGHealth CREATE WORKOUT SUCCESS HTTP \(httpResponse.statusCode)"
            )

        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.network(error.localizedDescription)
        }
    }

    // MARK: - Strength Sets

    struct StrengthSet: Identifiable, Codable, Hashable {
        let id: String
        let exerciseId: String
        let setOrder: Int
        let reps: Int
        let weightKg: Double
    }

    /// Adds a strength set inside an existing workout.
    ///
    /// `workoutId` is the ID of the parent HealthKit workout.
    /// The exercise is never created as a separate workout.
    func addStrengthSet(
        workoutId: String,
        id: String,
        exerciseId: String,
        setOrder: Int,
        reps: Int,
        weightKg: Double
    ) async throws {

        let url = baseURL
            .appendingPathComponent(
                "api/v1/fitness/workouts/\(workoutId)/sets"
            )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        setAuthorizationHeader(on: &request)

        request.setValue(
            "application/json",
            forHTTPHeaderField: "Content-Type"
        )

        // IMPORTANT:
        // The Swift-side argument remains `setOrder`.
        // The backend expects the JSON field `orderInWorkout`.
        struct CreateSetRequest: Encodable {
            let id: String
            let exerciseId: String
            let orderInWorkout: Int
            let reps: Int
            let weightKg: Double
        }

        let body = CreateSetRequest(
            id: id,
            exerciseId: exerciseId,
            orderInWorkout: setOrder,
            reps: reps,
            weightKg: weightKg
        )

        let encodedBody = try JSONEncoder().encode(body)
        request.httpBody = encodedBody

        print("")
        print("========================================")
        print("AGHealth ADD STRENGTH SET REQUEST")
        print("========================================")
        print("AGHealth URL:")
        print(url.absoluteString)
        print("AGHealth HTTP method:")
        print(request.httpMethod ?? "<none>")
        print("AGHealth workoutId:")
        print(workoutId)
        print("AGHealth exerciseId:")
        print(exerciseId)
        print("AGHealth setOrder:")
        print(setOrder)
        print("AGHealth reps:")
        print(reps)
        print("AGHealth weightKg:")
        print(weightKg)
        print("AGHealth request body:")
        print(
            String(
                data: encodedBody,
                encoding: .utf8
            ) ?? "<invalid UTF-8>"
        )
        print("========================================")
        print("AGHealth ADD STRENGTH SET: sending request")
        print("========================================")

        do {
            let (data, response) = try await URLSession.shared.data(
                for: request
            )

            guard let httpResponse = response as? HTTPURLResponse else {
                print(
                    "AGHealth ADD STRENGTH SET: invalid HTTP response"
                )

                throw APIError.invalidResponse
            }

            let responseBody = String(
                data: data,
                encoding: .utf8
            ) ?? "<empty response body>"

            print("")
            print("========================================")
            print("AGHealth ADD STRENGTH SET RESPONSE")
            print("========================================")
            print("AGHealth HTTP status:")
            print(httpResponse.statusCode)
            print("AGHealth response body:")
            print(responseBody)
            print("========================================")

            guard (200...299).contains(httpResponse.statusCode) else {

                print(
                    "AGHealth ADD STRENGTH SET FAILED"
                )
                print(
                    "AGHealth ADD STRENGTH SET HTTP \(httpResponse.statusCode)"
                )
                print(
                    "AGHealth ADD STRENGTH SET RESPONSE BODY:"
                )
                print(responseBody)

                throw APIError.httpStatus(
                    httpResponse.statusCode
                )
            }

            print(
                "AGHealth ADD STRENGTH SET SUCCESS HTTP \(httpResponse.statusCode)"
            )

        } catch let error as APIError {
            throw error
        } catch {
            print(
                "AGHealth ADD STRENGTH SET NETWORK ERROR:"
            )
            print(error)

            throw APIError.network(
                error.localizedDescription
            )
        }
    }

    // MARK: - Workouts (GET)

    struct Workout: Identifiable, Codable, Hashable {
        let id: String
        let workoutType: String
        let source: String
        let startedAt: String
        let durationSec: Int
        let distance: Double?
        let energyBurned: Double?
        let createdAt: String
        let updatedAt: String
    }

    struct SwimStyleBreakdown: Codable, Hashable, Identifiable {
        let style: String
        let label: String
        let distanceM: Double?
        let durationSec: Double?

        var id: String { style }
    }

    struct SwimmingBreakdown: Codable, Hashable {
        let styles: [SwimStyleBreakdown]
        let totalDistanceM: Double?
        let totalDurationSec: Double?
    }

    struct WorkoutDetail: Identifiable, Codable {
        let id: String
        let workoutType: String
        let source: String
        let startedAt: String
        let durationSec: Int
        let distance: Double?
        let energyBurned: Double?
        let createdAt: String
        let updatedAt: String
        let sets: [StrengthSetDetail]
        // Only present for swimming workouts with a HealthKit style breakdown.
        let swimming: SwimmingBreakdown?
        // «Мышечная нагрузка тренировки» — per-workout muscle load from the SAME backend
        // muscle-load layer as the weekly summary/body map. Optional so older backends decode.
        let muscleLoad: WorkoutMuscleLoad?
    }

    // Per-workout muscle load. Reuses MuscleGroupLoad/MuscleLoad (same `setEquivalents` field the
    // weekly summary uses) so the WorkoutDetail summary and the weekly analytics read identically.
    struct WorkoutMuscleLoad: Codable {
        struct Totals: Codable, Hashable {
            let strengthSets: Int
            let strengthVolume: Int?
            let cardioWorkouts: Int
            let workedGroups: Int
        }
        let totals: Totals
        let groups: [MuscleGroupLoad]
    }

    struct StrengthSetDetail: Identifiable, Codable, Hashable {
        let id: String
        let workoutId: String
        let exerciseId: String
        let exerciseName: String
        let muscleGroup: String?
        let orderInWorkout: Int
        let weightKg: Double
        let reps: Int
        let createdAt: String
        let updatedAt: String
    }

    func listWorkouts(
        type: String? = nil,
        from: Date? = nil,
        to: Date? = nil,
        limit: Int = 20,
        cursor: String? = nil
    ) async throws -> [Workout] {
        var url = baseURL
            .appendingPathComponent("api/v1/fitness/workouts")

        var queryItems: [URLQueryItem] = []

        if let type = type {
            queryItems.append(URLQueryItem(name: "type", value: type))
        }

        if let from = from {
            let formatter = ISO8601DateFormatter()
            queryItems.append(URLQueryItem(name: "from", value: formatter.string(from: from)))
        }

        if let to = to {
            let formatter = ISO8601DateFormatter()
            queryItems.append(URLQueryItem(name: "to", value: formatter.string(from: to)))
        }

        queryItems.append(URLQueryItem(name: "limit", value: "\(limit)"))

        if let cursor = cursor {
            queryItems.append(URLQueryItem(name: "cursor", value: cursor))
        }

        if !queryItems.isEmpty {
            url.append(queryItems: queryItems)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        setAuthorizationHeader(on: &request)

        do {
            let (data, response) = try await URLSession.shared.data(
                for: request
            )

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            guard httpResponse.statusCode == 200 else {
                throw APIError.httpStatus(httpResponse.statusCode)
            }

            struct WorkoutsResponse: Decodable {
                let workouts: [Workout]
            }

            let result = try JSONDecoder().decode(
                WorkoutsResponse.self,
                from: data
            )

            print("AGHealth: loaded \(result.workouts.count) workouts")

            return result.workouts

        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.network(error.localizedDescription)
        }
    }

    func getWorkout(id: String) async throws -> WorkoutDetail {
        let url = baseURL
            .appendingPathComponent("api/v1/fitness/workouts/\(id)")

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        setAuthorizationHeader(on: &request)

        do {
            let (data, response) = try await URLSession.shared.data(
                for: request
            )

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            guard httpResponse.statusCode == 200 else {
                throw APIError.httpStatus(httpResponse.statusCode)
            }

            struct WorkoutDetailResponse: Decodable {
                let workout: WorkoutDetail
            }

            let result = try JSONDecoder().decode(
                WorkoutDetailResponse.self,
                from: data
            )

            print("AGHealth: loaded workout detail with \(result.workout.sets.count) sets")

            return result.workout

        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.network(error.localizedDescription)
        }
    }

    // MARK: - Sleep

    struct SleepSegment: Codable, Hashable, Identifiable {
        let stage: String        // awake | rem | core | deep | asleep | inbed
        let label: String
        let startedAt: String
        let endedAt: String
        var id: String { "\(stage)|\(startedAt)" }
    }

    struct SleepSession: Codable, Hashable, Identifiable {
        let id: String
        let source: String
        let nightDate: String
        let startedAt: String
        let endedAt: String
        let inBedSec: Int?
        let asleepSec: Int
        let deepSec: Int?
        let coreSec: Int?
        let remSec: Int?
        let awakeSec: Int?
        let efficiency: Double?
        let segments: [SleepSegment]?
    }

    struct SleepRating: Codable, Hashable {
        let key: String
        let label: String
    }

    struct SleepDay: Codable {
        let hasData: Bool
        let goalSec: Int
        let goalPct: Int?
        let rating: SleepRating?
        let session: SleepSession?
    }

    struct SleepNight: Codable, Hashable, Identifiable {
        let nightDate: String
        let asleepSec: Int
        let inBedSec: Int?
        let deepSec: Int?
        let coreSec: Int?
        let remSec: Int?
        let awakeSec: Int?
        let efficiency: Double?
        var id: String { nightDate }
    }

    struct SleepWeek: Codable {
        struct StageAvg: Codable, Hashable {
            let deepSec: Int
            let coreSec: Int
            let remSec: Int
            let awakeSec: Int
        }
        struct Averages: Codable {
            let asleepSec: Int
            let asleepHours: Double
            let efficiency: Double?
            let stage: StageAvg?
            let nightsCount: Int
        }
        let hasData: Bool
        let days: Int
        let goalSec: Int
        let nights: [SleepNight]
        let averages: Averages?
    }

    struct SleepSegmentInput: Encodable {
        let stage: String
        let startedAt: Date
        let endedAt: Date
    }

    /// Idempotent upsert of one night's sleep session (HealthKit-derived id).
    func createSleepSession(
        id: String,
        nightDate: String,
        startedAt: Date,
        endedAt: Date,
        inBedSec: Int?,
        asleepSec: Int,
        deepSec: Int?,
        coreSec: Int?,
        remSec: Int?,
        awakeSec: Int?,
        segments: [SleepSegmentInput]
    ) async throws {
        let url = baseURL.appendingPathComponent("api/v1/sleep/sessions")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        setAuthorizationHeader(on: &request)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        struct Body: Encodable {
            let id: String
            let source: String
            let nightDate: String
            let startedAt: Date
            let endedAt: Date
            let inBedSec: Int?
            let asleepSec: Int
            let deepSec: Int?
            let coreSec: Int?
            let remSec: Int?
            let awakeSec: Int?
            let segments: [SleepSegmentInput]
        }
        let body = Body(
            id: id, source: "healthkit", nightDate: nightDate,
            startedAt: startedAt, endedAt: endedAt, inBedSec: inBedSec,
            asleepSec: asleepSec, deepSec: deepSec, coreSec: coreSec,
            remSec: remSec, awakeSec: awakeSec, segments: segments
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
            guard (200...299).contains(http.statusCode) else {
                let bodyText = String(data: data, encoding: .utf8) ?? ""
                print("AGHealth SLEEP POST HTTP \(http.statusCode): \(bodyText)")
                throw APIError.httpStatus(http.statusCode)
            }
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.network(error.localizedDescription)
        }
    }

    func fetchSleepDay() async throws -> SleepDay {
        try await getDecoded(path: "api/v1/sleep/day", type: SleepDay.self)
    }

    func fetchSleepWeek(days: Int = 7) async throws -> SleepWeek {
        var url = baseURL.appendingPathComponent("api/v1/sleep/week")
        url.append(queryItems: [URLQueryItem(name: "days", value: "\(days)")])
        return try await getDecoded(url: url, type: SleepWeek.self)
    }

    // MARK: - Recovery

    struct Recovery: Codable {
        struct SleepFactor: Codable {
            let score: Int
            let asleepSec: Int
            let efficiency: Double?
            let nightDate: String
        }
        struct LoadFactor: Codable {
            let points: Double
            let workouts: Int
            let penalty: Int
            let lookbackHours: Int
        }
        struct NutritionFactor: Codable {
            let available: Bool
            let note: String
        }
        struct Factors: Codable {
            let sleep: SleepFactor?
            let trainingLoad: LoadFactor?
            let nutrition: NutritionFactor?
        }
        let hasData: Bool
        let reason: String?
        let message: String?
        let score: Int?
        let band: String?
        let bandLabel: String?
        let verdict: String?
        let factors: Factors?
    }

    func fetchRecovery() async throws -> Recovery {
        try await getDecoded(path: "api/v1/recovery", type: Recovery.self)
    }

    // MARK: - Helpers

    private func getDecoded<T: Decodable>(path: String, type: T.Type) async throws -> T {
        let url = baseURL.appendingPathComponent(path)
        return try await getDecoded(url: url, type: type)
    }

    private func getDecoded<T: Decodable>(url: URL, type: T.Type) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        setAuthorizationHeader(on: &request)
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
            guard http.statusCode == 200 else { throw APIError.httpStatus(http.statusCode) }
            return try JSONDecoder().decode(T.self, from: data)
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.network(error.localizedDescription)
        }
    }

    private func setAuthorizationHeader(
        on request: inout URLRequest
    ) {
        request.setValue(
            "Bearer \(token)",
            forHTTPHeaderField: "Authorization"
        )
    }
}

// MARK: - Errors

enum APIError: LocalizedError {
    case invalidResponse
    case httpStatus(Int)
    case network(String)
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Некорректный ответ сервера"

        case .httpStatus(let status):
            return "HTTP ошибка: \(status)"

        case .network(let message):
            return "Сетевая ошибка: \(message)"

        case .decodingFailed:
            return "Не удалось прочитать ответ сервера"
        }
    }
}
