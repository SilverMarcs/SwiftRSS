//
//  OnboardingView.swift
//  SwiftRSS
//
//  Created by Zabir Raihan on 02/04/2026.
//

import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    @State private var showFeedPicker = false

    var body: some View {
        if showFeedPicker {
            FeedPickerPage {
                hasCompletedOnboarding = true
            }
            #if os(macOS)
            .frame(width: 450, height: 500)
            #endif
        } else {
            WelcomePage {
                showFeedPicker = true
            }
        }
    }
}
