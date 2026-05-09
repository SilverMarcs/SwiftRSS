//
//  Toolbar++.swift
//  SwiftRSS
//
//  Created by Zabir Raihan on 15/09/2025.
//

import SwiftUI

extension ToolbarItemPlacement {
    /// A cross-platform toolbar placement that adapts to the platform:
    /// - iOS: Uses `.bottomBar` for bottom placement
    /// - macOS: Uses `.automatic` for appropriate placement
    static var platformBar: ToolbarItemPlacement {
        #if os(iOS)
        return .bottomBar
        #else
        return .automatic
        #endif
    }
}
