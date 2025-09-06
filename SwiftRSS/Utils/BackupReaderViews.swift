//
//  ArticleReaderView.swift
//  SwiftRSS
//
//  Created by Zabir Raihan on 06/09/2025.
//


//import SafariServices
//
//struct ArticleReaderView: UIViewControllerRepresentable {
//    let article: Article
//    let onDismiss: () -> Void
//
//    func makeCoordinator() -> Coordinator {
//        Coordinator(self)
//    }
//
//    func makeUIViewController(context: Context) -> SFSafariViewController {
//        article.isRead = true
//        
//        let config = SFSafariViewController.Configuration()
//        config.entersReaderIfAvailable = true
//        config.barCollapsingEnabled = false
//
//        let safari = SFSafariViewController(url: article.link, configuration: config)
//        safari.delegate = context.coordinator
//        return safari
//    }
//
//    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
//
//    class Coordinator: NSObject, SFSafariViewControllerDelegate {
//        let parent: ArticleReaderView
//
//        init(_ parent: ArticleReaderView) {
//            self.parent = parent
//        }
//
//        func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
//            parent.onDismiss()
//        }
//    }
//}


////
////  ArticleReaderView.swift
////  SwiftRSS
////
////  Created by Zabir Raihan on 06/09/2025.
////
//
//import SwiftUI
//import WebKit
//
//struct ArticleReaderView: View {
//    let article: Article
//    
//    @State private var page = WebPage()
//    
//    var body: some View {
//        WebView(page)
//            .navigationTitle(page.title)
//            .toolbarTitleDisplayMode(.inline)
//            .task {
//                
//                Task {
//                    let request = URLRequest(url: article.link)
//                    for try await event in page.load(request) {
//                        if case .finished = event {
//                            await injectDarkModeCSS()
//                        }
//                    }
//                }
//            }
//    }
//    
//    private func injectDarkModeCSS() async {
//        let css = """
//        @media (prefers-color-scheme: dark) {
//            body {
//                background-color: #1a1a1a !important;
//                color: #e0e0e0 !important;
//            }
//            a {
//                color: #4a9eff !important;
//            }
//            h1, h2, h3, h4, h5, h6 {
//                color: #eeeeee !important;
//            }
//        }
//        """
//        let script = """
//        var style = document.createElement('style');
//        style.textContent = `\(css)`;
//        document.head.appendChild(style);
//        """
//        do {
//            try await page.callJavaScript(script)
//        } catch {
//            print("Failed to inject CSS: \(error)")
//        }
//    }
//}
