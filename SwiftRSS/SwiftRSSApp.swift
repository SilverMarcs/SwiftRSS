//
//  SwiftRSSApp.swift
//  SwiftRSS
//
//  Created by Zabir Raihan on 05/09/2025.
//

import SwiftUI
import SwiftData

@main
struct SwiftRSSApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedContainer)
    }
}

let sharedContainer: ModelContainer = {
    let schema = Schema([Feed.self, Article.self])
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
    return try! ModelContainer(for: schema, configurations: [config])
}()
