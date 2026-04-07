//
//  SwiftRSSApp.swift
//  SwiftRSS
//
//  Created by Zabir Raihan on 05/09/2025.
//

import SwiftUI
import SwiftData

@main
struct FeedDeckApp: App {
    let container: ModelContainer
    @State var store: FeedStore

    init() {
        let container = try! ModelContainer(
            for: Feed.self, Article.self,
            configurations: ModelConfiguration(cloudKitDatabase: .automatic)
        )
        self.container = container
        self._store = State(initialValue: FeedStore(modelContext: container.mainContext))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .modelContainer(container)
        }

        #if os(macOS)
        Settings {
            SettingsView()
                .environment(store)
                .modelContainer(container)
        }
        #endif
    }
}
