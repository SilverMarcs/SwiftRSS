//
//  SwiftRSSApp.swift
//  SwiftRSS
//
//  Created by Zabir Raihan on 05/09/2025.
//

import SwiftUI
import Observation

@main
struct SwiftRSSApp: App {
    @State var store = FeedStore()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
        }
        
        #if os(macOS)
        Settings {
            SettingsView()
                .environment(store)
        }
        #endif
    }
}
