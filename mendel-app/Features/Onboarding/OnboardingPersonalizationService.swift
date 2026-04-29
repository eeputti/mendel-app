#if !WIDGET_EXTENSION
//
// OnboardingPersonalizationService.swift
// Optional edge-function-backed onboarding personalization.
//

import Foundation

struct OnboardingPersonalizationService {
    private static let fallbackFunctionsBaseURL = "https://eagkefzfmqklryzpuyvm.supabase.co/functions/v1/"

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func buildPersonalization(
        profile: OnboardingProfile,
        derivedProfile: DerivedCoachingProfile
    ) async throws -> OnboardingPersonalizationResult {
        let url = try functionBaseURL().appendingPathComponent("onboarding-personalization")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            OnboardingPersonalizationRequest(
                profile: profile,
                derived_profile: derivedProfile
            )
        )

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CoachServiceError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw CoachServiceError.backendError(
                httpResponse.statusCode,
                nil,
                String(data: data, encoding: .utf8)
            )
        }

        return try JSONDecoder().decode(OnboardingPersonalizationResult.self, from: data)
    }

    private func functionBaseURL() throws -> URL {
        let plistValue = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_FUNCTIONS_BASE_URL") as? String
        let normalized = (plistValue?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? plistValue! : Self.fallbackFunctionsBaseURL)
            .replacingOccurrences(of: "/+$", with: "", options: .regularExpression)
        guard let url = URL(string: normalized) else {
            throw CoachServiceError.invalidBaseURL(normalized)
        }
        return url
    }
}

private struct OnboardingPersonalizationRequest: Encodable {
    let profile: OnboardingProfile
    let derived_profile: DerivedCoachingProfile
}
#endif
