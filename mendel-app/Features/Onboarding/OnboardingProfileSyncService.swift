#if !WIDGET_EXTENSION
//
// OnboardingProfileSyncService.swift
// Reserved hook for authenticated backend profile persistence.
//

import Foundation

struct OnboardingProfileSyncService {
    func syncIfPossible(profile: OnboardingProfile, derivedProfile: DerivedCoachingProfile) async {
        _ = profile
        _ = derivedProfile

        // TODO: Persist onboarding answers into the authenticated Supabase `profiles`
        // row once in-app auth is wired. Until then, onboarding is saved locally,
        // seeded into plan defaults, and attached to coach requests as supplemental context.
    }
}
#endif
