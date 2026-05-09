//
//  LynkSphereByline.swift
//  SwiftRSS
//
//  Created by Zabir Raihan on 07/04/2026.
//

import SwiftUI

struct LynkSphereByline: View {
    var body: some View {
        HStack(spacing: 6) {
            Text("by")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Image("LynkSphereLogo")
                .resizable()
                .scaledToFit()
                .frame(height: 24)

            Text("LynkSphere")
                .font(.subheadline.weight(.semibold))
        }
    }
}
