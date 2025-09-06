//
//  Environment++.swift
//  SwiftRSS
//
//  Created by Zabir Raihan on 06/09/2025.
//

import SwiftUI

extension EnvironmentValues {
    @Entry var appendToPath: ((any Hashable) -> Void) = { _ in
        print("No path append handler provided")
    }
}
