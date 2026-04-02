//
//  OnboardingView.swift
//  SwiftRSS
//
//  Created by Zabir Raihan on 02/04/2026.
//

import SwiftUI

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool

    @State private var showFeedPicker = false

    var body: some View {
        if showFeedPicker {
            FeedPickerPage {
                hasCompletedOnboarding = true
            }
        } else {
            WelcomePage {
                withAnimation {
                    showFeedPicker = true
                }
            }
        }
    }
}
