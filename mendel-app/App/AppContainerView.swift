#if !WIDGET_EXTENSION
//
// AppContainerView.swift
// Chooses between onboarding and the main tab experience.
//

import SwiftUI

struct AppContainerView: View {
    @Environment(OnboardingStore.self) private var onboardingStore

    var body: some View {
        Group {
            if onboardingStore.isCompleted {
                RootTabView()
            } else {
                OnboardingFlowView(store: onboardingStore)
            }
        }
        .background(MendelColors.bg)
    }
}
#endif
