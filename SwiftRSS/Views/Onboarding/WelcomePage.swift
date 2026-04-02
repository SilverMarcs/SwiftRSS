//
//  WelcomePage.swift
//  SwiftRSS
//
//  Created by Zabir Raihan on 02/04/2026.
//

import SwiftUI

struct WelcomePage: View {
    var onContinue: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 12) {
                Image(systemName: "dot.radiowaves.up.forward")
                    .font(.system(size: 64))
                    .foregroundStyle(.accent)

                Text("Welcome to SwiftRSS")
                    .font(.largeTitle.bold())

                Text("Your feeds, all in one place.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 20) {
                featureRow(
                    icon: "plus.circle.fill",
                    color: .blue,
                    title: "Subscribe to Feeds",
                    subtitle: "Add RSS, Atom, or XML feeds"
                )
                featureRow(
                    icon: "arrow.clockwise.circle.fill",
                    color: .green,
                    title: "Stay Updated",
                    subtitle: "Articles refresh automatically"
                )
                featureRow(
                    icon: "star.circle.fill",
                    color: .orange,
                    title: "Read Your Way",
                    subtitle: "Star, filter, and get AI summaries"
                )
            }
            .padding(.horizontal, 32)

            Spacer()

            Button {
                onContinue()
            } label: {
                Text("Get Started")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
    }

    private func featureRow(icon: String, color: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title)
                .foregroundStyle(color)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
