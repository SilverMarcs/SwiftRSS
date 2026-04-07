//
//  WelcomePage.swift
//  SwiftRSS
//
//  Created by Zabir Raihan on 02/04/2026.
//

import SwiftUI

struct WelcomePage: View {
    var onContinue: () -> Void

    @State private var showByLine = false

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            VStack(spacing: 12) {
                Image(systemName: "dot.radiowaves.up.forward")
                    .font(.system(size: 64))
                    .bold()
                    .foregroundStyle(.accent)
                
                VStack(spacing: 5) {
                    Text("Welcome to FeedDeck")
                        .font(.largeTitle.bold())
                    
                    
                    Text("Your feeds, all in one place.")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                }
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

            VStack(spacing: 16) {
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

                LynkSphereByline()
                    .opacity(showByLine ? 1 : 0)
                    .offset(y: showByLine ? 0 : 8)
            }
            .padding(.bottom, 32)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8).delay(0.5)) {
                showByLine = true
            }
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
