//
//  NavigationDestinations.swift
//  SwiftRSS
//
//  Created by Zabir Raihan on 06/09/2025.
//

import SwiftUI

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
                SafariView(url: article.link) {
                    path.wrappedValue.removeLast()
                }
                .onAppear {
                    article.isRead = true
                }
                .ignoresSafeArea()
                .navigationBarBackButtonHidden()
            }
    }
}
