import Foundation

final class XMLFeedParser: NSObject, XMLParserDelegate {
    private let data: Data
    private let baseURL: URL

    // State
    private var stack: [String] = []
    private var currentText: String = ""

    // RSS
    private var rssMeta = FeedMeta()
    private var rssItems: [FeedItem] = []
    private var currentItem: FeedItem?

    // Atom
    private var atomMeta = FeedMeta()
    private var atomItems: [FeedItem] = []
    private var atomCurrent: FeedItem?

    init(data: Data, baseURL: URL) {
        self.data = data
        self.baseURL = baseURL
        
        // Debug: Print raw data as string if needed
        // if let rawString = String(data: data, encoding: .utf8) {
        //     print("=== RAW FEED DATA ===")
        //     print(rawString)
        //     print("=== END RAW DATA ===\n")
        // }
    }

    func parseRSS2() throws -> (FeedMeta, [FeedItem]) {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        
        // Add favicon fallback if no thumbnail found
        if rssMeta.thumbnailURL == nil {
            rssMeta.thumbnailURL = getFaviconURL()
        }
        
        return (rssMeta, rssItems)
    }

    func parseAtom() throws -> (FeedMeta, [FeedItem]) {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        
        // Add favicon fallback if no thumbnail found
        if atomMeta.thumbnailURL == nil {
            atomMeta.thumbnailURL = getFaviconURL()
        }
        
        return (atomMeta, atomItems)
    }

    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName qName: String?, attributes attr: [String : String] = [:]) {
        stack.append(name.lowercased())
        currentText = ""

        // Atom <link href="">
        if stack.suffix(2) == ["entry","link"], let href = attr["href"], let url = URL(string: href, relativeTo: baseURL) {
            atomCurrent?.link = url.absoluteURL
        }

        // RSS enclosure for media (like featured images)
        if stack.suffix(2) == ["item","enclosure"],
           let urlString = attr["url"],
           let type = attr["type"],
           type.hasPrefix("image/"),
           let url = URL(string: urlString, relativeTo: baseURL) {
            currentItem?.featuredImageURL = url.absoluteURL
        }

        if stack.suffix(1) == ["item"] && currentItem == nil {
            currentItem = FeedItem(title: "", link: baseURL, contentHTML: nil, author: nil, publishedAt: nil, featuredImageURL: nil)
        }
        if stack.suffix(1) == ["entry"] && atomCurrent == nil {
            atomCurrent = FeedItem(title: "", link: baseURL, contentHTML: nil, author: nil, publishedAt: nil, featuredImageURL: nil)
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName qName: String?) {
        let path = stack.map { $0 }
        let lower = name.lowercased()
        defer { _ = stack.popLast() }

        let text = currentText.trimmingCharacters(in: .whitespacesAndNewlines)

        // RSS channel
        if path == ["rss","channel","title"] { rssMeta.title = text }
        if path == ["rss","channel","image","url"], let u = URL(string: text, relativeTo: baseURL) { rssMeta.thumbnailURL = u.absoluteURL }

        // RSS item
        if path.suffix(2) == ["item","title"] { currentItem?.title = text }
        if path.suffix(2) == ["item","link"], let u = URL(string: text, relativeTo: baseURL) { currentItem?.link = u.absoluteURL }
        if path.suffix(2) == ["item","description"] {
            // Try to extract featured image from description HTML
            if currentItem?.featuredImageURL == nil {
                currentItem?.featuredImageURL = extractImageFromHTML(text)
            }
        }
        if path.suffix(2) == ["item","content:encoded"] {
            currentItem?.contentHTML = text
            // Try to extract featured image from content HTML if not already found
            if currentItem?.featuredImageURL == nil {
                currentItem?.featuredImageURL = extractImageFromHTML(text)
            }
        }
        if path.suffix(2) == ["item","author"] { currentItem?.author = text }
        if path.suffix(2) == ["item","dc:creator"] { currentItem?.author = text }
        if path.suffix(2) == ["item","pubdate"] || path.suffix(2) == ["item","published"] {
            currentItem?.publishedAt = RFCDate.parse(text)
        }
        
        // Media RSS namespace for featured images
        if path.suffix(2) == ["item","media:content"] || path.suffix(2) == ["item","media:thumbnail"] {
            if let url = URL(string: text, relativeTo: baseURL) {
                currentItem?.featuredImageURL = url.absoluteURL
            }
        }
        
        if lower == "item" {
            if let item = currentItem {
                rssItems.append(item)
            }
            currentItem = nil
        }

        // Atom feed
        if path.suffix(2) == ["feed","title"] { atomMeta.title = text }
        if path.suffix(2) == ["feed","logo"], let u = URL(string: text, relativeTo: baseURL) { atomMeta.thumbnailURL = u.absoluteURL }
        if path.suffix(2) == ["feed","icon"], let u = URL(string: text, relativeTo: baseURL) { atomMeta.thumbnailURL = u.absoluteURL }

        // Atom entry
        if path.suffix(2) == ["entry","title"] { atomCurrent?.title = text }
        if path.suffix(2) == ["entry","summary"] {
            if atomCurrent?.featuredImageURL == nil {
                atomCurrent?.featuredImageURL = extractImageFromHTML(text)
            }
        }
        if path.suffix(2) == ["entry","content"] {
            atomCurrent?.contentHTML = text
            if atomCurrent?.featuredImageURL == nil {
                atomCurrent?.featuredImageURL = extractImageFromHTML(text)
            }
        }
        if path.suffix(2) == ["entry","author"] { atomCurrent?.author = text }
        if path.suffix(2) == ["entry","published"] { atomCurrent?.publishedAt = RFCDate.parse(text) }
        if lower == "entry" {
            if let item = atomCurrent {
                atomItems.append(item)
            }
            atomCurrent = nil
        }

        currentText = ""
    }
    
    // Helper function to extract first image URL from HTML content
    private func extractImageFromHTML(_ html: String) -> URL? {
        // Look for <img src="..." or <div class="feat-image"><img src="..."
        let patterns = [
            #"<img[^>]+src=["\']([^"\']+)["\']"#,
            #"<div[^>]*class=["\'][^"\']*feat-image[^"\']*["\'][^>]*>.*?<img[^>]+src=["\']([^"\']+)["\']"#
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]),
               let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)) {
                let range = match.range(at: 1)
                if let swiftRange = Range(range, in: html) {
                    let urlString = String(html[swiftRange])
                    if let url = URL(string: urlString, relativeTo: baseURL) {
                        return url.absoluteURL
                    }
                }
            }
        }
        return nil
    }
    
    // Helper function to generate favicon URL as fallback
    private func getFaviconURL() -> URL? {
        // Create base URL components (removes path, keeps domain)
        var components = URLComponents()
        components.scheme = baseURL.scheme
        components.host = baseURL.host
        components.port = baseURL.port
        
        guard let baseHost = components.url else { return nil }
        
        // Try common favicon paths in order of preference
        let faviconPaths = [
            "/favicon.ico",           // Most common
            "/favicon.png",           // PNG alternative
            "/apple-touch-icon.png",  // Apple touch icon
            "/favicon-32x32.png",     // Specific size
            "/favicon-16x16.png"      // Smaller size
        ]
        
        // Return the first favicon path (most likely to exist)
        return URL(string: faviconPaths[0], relativeTo: baseHost)?.absoluteURL
    }
}
