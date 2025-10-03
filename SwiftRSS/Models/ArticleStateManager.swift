//
//  ArticleStateManager.swift
//  SwiftRSS
//
//  Created by Zabir Raihan on 03/10/2025.
//

import Foundation

@Observable
final class ArticleStateManager {
    static let shared = ArticleStateManager()
    
    private let defaults = UserDefaults.standard
    private let statesKey = "articleStates_v2"
    
    // Published property for SwiftUI reactivity
    var states: [String: ArticleState] = [:] { didSet { persistStates() } }
    
    private init() {
        loadStates()
    }
    
    private func loadStates() {
        if let data = defaults.data(forKey: statesKey),
           let decoded = try? JSONDecoder().decode([String: ArticleState].self, from: data) {
            states = decoded
        }
    }
    
    private func persistStates() {
        if let data = try? JSONEncoder().encode(states) {
            defaults.set(data, forKey: statesKey)
        }
    }
    
    func getState(for articleID: String) -> ArticleState? {
        states[articleID]
    }
    
    func setRead(articleID: String, _ isRead: Bool) {
        var state = states[articleID] ?? ArticleState()
        state.isRead = isRead
        states[articleID] = state
    }
    
    func toggleRead(articleID: String) {
        var state = states[articleID] ?? ArticleState()
        state.isRead.toggle()
        states[articleID] = state
    }
    
    func toggleStar(articleID: String) {
        var state = states[articleID] ?? ArticleState()
        state.isStarred.toggle()
        states[articleID] = state
    }
}
