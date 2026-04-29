#if !WIDGET_EXTENSION
//
// CoachService.swift
// Fetches coach recommendations from Supabase Edge Functions.
//

import Foundation

struct CoachService {
    private static let fallbackFunctionsBaseURL = "https://eagkefzfmqklryzpuyvm.supabase.co/functions/v1/"

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchCoachRecommendation(trainingContext: CoachTrainingContext) async throws -> CoachResponse {
        try await post(
            functionName: "coach-recommendation",
            body: trainingContext,
            responseType: CoachResponse.self
        )
    }

    func sendCoachChat(
        message: String,
        history: [CoachMessage],
        trainingContext: CoachTrainingContext,
        userId: String?
    ) async throws -> String {
        let payload = CoachChatRequest(
            message: message,
            userId: userId,
            history: history.map { CoachChatHistoryItem(role: $0.role, content: $0.content) },
            context: CoachChatContext(
                training: trainingContext,
                profile: nil,
                onboarding: nil,
                plan: nil
            )
        )

        let response: CoachChatResponse = try await post(
            functionName: "coach-chat",
            body: payload,
            responseType: CoachChatResponse.self
        )

        return response.reply
    }

    private func functionURL() throws -> URL {
        debugLog("Bundle identifier: \(Bundle.main.bundleIdentifier ?? "<nil>")")

        let plistValue = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_FUNCTIONS_BASE_URL")
        debugLog("Info.plist SUPABASE_FUNCTIONS_BASE_URL: \(String(describing: plistValue))")

        let configuredValue = (plistValue as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseValue = configuredValue?.isEmpty == false ? configuredValue! : Self.fallbackFunctionsBaseURL
        let normalizedValue = baseValue.replacingOccurrences(
            of: "/+$",
            with: "",
            options: .regularExpression
        )
        debugLog("Using base URL: \(normalizedValue)")

        guard let baseURL = URL(string: normalizedValue) else {
            throw CoachServiceError.invalidBaseURL(normalizedValue)
        }

        if let projectURL = projectURL(fromFunctionsBaseURL: baseURL) {
            debugLog("Derived Supabase project URL: \(projectURL.absoluteString)")
        } else {
            debugLog("Derived Supabase project URL: <unable to derive from base URL>")
        }

        return baseURL
    }

    private func supabaseAnonKey() throws -> String {
        let plistValue = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY")
        debugLog("Info.plist SUPABASE_ANON_KEY present: \(plistValue != nil)")

        guard let anonKey = (plistValue as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !anonKey.isEmpty else {
            throw CoachServiceError.missingAnonKey
        }

        return anonKey
    }

    private func post<RequestBody: Encodable, ResponseBody: Decodable>(
        functionName: String,
        body: RequestBody,
        responseType: ResponseBody.Type
    ) async throws -> ResponseBody {
        let baseURL = try functionURL()
        let anonKey = try supabaseAnonKey()
        let url = baseURL.appendingPathComponent(functionName)
        debugLog("Function name: \(functionName)")
        debugLog("Final request URL: \(url.absoluteString)")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        let requestBody = try JSONEncoder().encode(body)
        request.httpBody = requestBody
        debugLog("Request body: \(String(decoding: requestBody, as: UTF8.self))")

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw mapTransportError(error)
        }
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CoachServiceError.invalidResponse
        }

        let responseBody = String(data: data, encoding: .utf8)
        debugLog("Response status: \(httpResponse.statusCode)")
        debugLog("Raw response body: \(responseBody ?? "<non-UTF8 body>")")

        guard (200...299).contains(httpResponse.statusCode) else {
            let serverError = try? JSONDecoder().decode(CoachChatErrorResponse.self, from: data)
            let errorCode = serverError?.error.code

            switch httpResponse.statusCode {
            case 401, 403:
                throw CoachServiceError.unauthorized(serverError?.request_id)
            case 408, 504:
                throw CoachServiceError.timedOut(serverError?.request_id)
            case 500...599 where errorCode == "invalid_response":
                throw CoachServiceError.invalidResponse
            case 500...599:
                throw CoachServiceError.backendUnavailable(serverError?.request_id)
            default:
                break
            }

            throw CoachServiceError.backendError(
                httpResponse.statusCode,
                serverError,
                responseBody
            )
        }

        do {
            return try JSONDecoder().decode(responseType, from: data)
        } catch {
            debugLog("Decode error: \(error)")
            throw CoachServiceError.decodingFailed(error, responseBody)
        }
    }

    private func debugLog(_ message: String) {
        #if DEBUG
        print("[CoachService] \(message)")
        #endif
    }

    private func mapTransportError(_ error: Error) -> CoachServiceError {
        guard let urlError = error as? URLError else {
            return .backendError(-1, nil, error.localizedDescription)
        }

        switch urlError.code {
        case .notConnectedToInternet, .networkConnectionLost, .internationalRoamingOff, .dataNotAllowed:
            return .offline
        case .timedOut:
            return .timedOut(nil)
        default:
            return .backendError(urlError.errorCode, nil, urlError.localizedDescription)
        }
    }

    private func projectURL(fromFunctionsBaseURL url: URL) -> URL? {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }

        components.path = ""
        components.query = nil
        components.fragment = nil
        return components.url
    }
}

enum CoachServiceError: Error {
    case missingBaseURL
    case missingAnonKey
    case invalidBaseURL(String)
    case invalidResponse
    case unauthorized(String?)
    case offline
    case timedOut(String?)
    case backendUnavailable(String?)
    case backendError(Int, CoachChatErrorResponse?, String?)
    case decodingFailed(Error, String?)
}

extension CoachServiceError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .missingBaseURL:
            return "Missing SUPABASE_FUNCTIONS_BASE_URL in the app configuration."
        case .missingAnonKey:
            return "Missing SUPABASE_ANON_KEY in the app configuration."
        case let .invalidBaseURL(value):
            return "Invalid SUPABASE_FUNCTIONS_BASE_URL: \(value)"
        case .invalidResponse:
            return "The Coach service returned an invalid response."
        case let .unauthorized(requestID):
            return "Coach request was unauthorized\(requestID.map { " [request_id: \($0)]" } ?? "")."
        case .offline:
            return "The network appears to be offline."
        case let .timedOut(requestID):
            return "The Coach service timed out\(requestID.map { " [request_id: \($0)]" } ?? "")."
        case let .backendUnavailable(requestID):
            return "The Coach service is temporarily unavailable\(requestID.map { " [request_id: \($0)]" } ?? "")."
        case let .backendError(statusCode, payload, body):
            let requestSuffix = payload?.request_id.map { " [request_id: \($0)]" } ?? ""
            if let message = payload?.error.message, !message.isEmpty {
                return "Coach request failed (\(statusCode))\(requestSuffix): \(message)"
            }
            if let body, !body.isEmpty {
                return "Coach request failed (\(statusCode))\(requestSuffix): \(body)"
            }
            return "Coach request failed with status \(statusCode)\(requestSuffix)."
        case let .decodingFailed(error, _):
            return "Coach response could not be decoded: \(error.localizedDescription)"
        }
    }
}
#endif
