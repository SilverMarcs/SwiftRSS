import Foundation

enum URLNormalizer {
    // Returns a canonical string for use as a stable Article ID.
    static func normalizedArticleID(from url: URL) -> String {
        guard var comps = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url.absoluteString
        }

        // Lowercase scheme + host
        comps.scheme = comps.scheme?.lowercased()
        comps.host = comps.host?.lowercased()

        // Remove default ports
        if let scheme = comps.scheme, let port = comps.port {
            if (scheme == "http" && port == 80) || (scheme == "https" && port == 443) {
                comps.port = nil
            }
        }

        // Remove fragment
        comps.fragment = nil

        // Sort and filter query items and drop tracking params
        if let items = comps.queryItems, !items.isEmpty {
            let filtered = items
                .filter { item in
                    guard let name = item.name.lowercased() as String? else { return false }
                    if trackingParams.contains(name) { return false }
                    // Drop empty values
                    if (item.value ?? "").isEmpty { return false }
                    return true
                }
                .sorted { $0.name.lowercased() < $1.name.lowercased() }
            comps.queryItems = filtered.isEmpty ? nil : filtered
        }

        // Normalize path: remove trailing slash unless root
        if var path = comps.percentEncodedPath.removingPercentEncoding {
            if path.count > 1 && path.hasSuffix("/") {
                path.removeLast()
            }
            comps.percentEncodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
        }

        // Prefer absoluteString of composed URL; fallback to original
        return comps.url?.absoluteString ?? url.absoluteString
    }

    private static let trackingParams: Set<String> = [
        // Common marketing/analytics params
        "utm_source", "utm_medium", "utm_campaign", "utm_term", "utm_content",
        "gclid", "fbclid", "yclid", "mc_cid", "mc_eid", "ref", "igshid"
    ]
}

