//
//  NavigationDestinations.swift
//  SwiftRSS
//
//  Created by Zabir Raihan on 06/09/2025.
//

import SwiftUI
import SwiftData

extension View {
    private func commonDestinationModifiers(path: Binding<NavigationPath>) -> some View {
        self
            .environment(\.appendToPath, { value in
                path.wrappedValue.append(value)
            })
    }
    
    func navigationDestinations(path: Binding<NavigationPath>) -> some View {
        self
            .commonDestinationModifiers(path: path)
            .navigationDestination(for: ArticleFilter.self) { filter in
                ArticleListView(filter: filter)
                    .commonDestinationModifiers(path: path)
            }
            .navigationDestination(for: Article.self) { article in
                ArticleReaderView(article: article) {
                    path.wrappedValue.removeLast()
                }
                    .commonDestinationModifiers(path: path)
                    .ignoresSafeArea()
                    .navigationBarBackButtonHidden()
            }
    }
}
