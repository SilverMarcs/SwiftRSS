//
//  SafariView.swift
//  SwiftRSS
//
//  Created by Zabir Raihan on 06/09/2025.
//

import SwiftUI
import SafariServices

struct SafariView: UIViewControllerRepresentable {
    let url: URL
    var onDismiss: (() -> Void)

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = true

        let safari = SFSafariViewController(url: url, configuration: config)
        safari.delegate = context.coordinator
        return safari
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}

    class Coordinator: NSObject, SFSafariViewControllerDelegate {
        let parent: SafariView

        init(_ parent: SafariView) {
            self.parent = parent
        }

        func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
            parent.onDismiss()
        }
    }
}
