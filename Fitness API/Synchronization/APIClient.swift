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

    struct Exercise: Identifiable, Codable, Hashable {
        let id: String
        let name: String
        let muscleGroup: String?
        let legacyKey: String?
        let archivedAt: String?

        var isArchived: Bool {
            archivedAt != nil
        }
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

    // MARK: - Workouts

    func createWorkout(
        id: String,
        workoutType: String,
        startedAt: Date,
        durationSec: Int,
        source: String,
        distance: Double?,
        energyBurned: Double?
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
        }

        let body = CreateWorkoutRequest(
            id: id,
            workoutType: workoutType,
            startedAt: startedAt,
            durationSec: durationSec,
            source: source,
            distance: distance,
            energyBurned: energyBurned
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

    // MARK: - Helpers

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
