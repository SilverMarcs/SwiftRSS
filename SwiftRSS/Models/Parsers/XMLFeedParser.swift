import Foundation

final class XMLFeedParser: NSObject, XMLParserDelegate {
    private let data: Data
    private let baseURL: URL
    private let maxItems: Int = 50

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
    
    // Cached regex for efficiency
    private lazy var imgRegex: NSRegularExpression? = {
        try? NSRegularExpression(pattern: #"<img[^>]+src=["\']([^"\']+)["\']"#, options: .caseInsensitive)
    }()

    init(data: Data, baseURL: URL) {
        self.data = data
        self.baseURL = baseURL
    }

    func parseRSS2() throws -> (FeedMeta, [FeedItem]) {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        
        if rssMeta.thumbnailURL == nil {
            rssMeta.thumbnailURL = getFaviconURL()
        }
        
        return (rssMeta, rssItems)
    }

    func parseAtom() throws -> (FeedMeta, [FeedItem]) {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        
        if atomMeta.thumbnailURL == nil {
            atomMeta.thumbnailURL = getFaviconURL()
        }
        
        return (atomMeta, atomItems)
    }

    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName qName: String?, attributes attr: [String : String] = [:]) {
        let lowerName = name.lowercased()
        stack.append(lowerName)
        currentText = ""

        // Atom <link href="">
        if lowerName == "link" && stack.count >= 2 && stack[stack.count - 2] == "entry",
           let href = attr["href"], let url = URL(string: href, relativeTo: baseURL) {
            atomCurrent?.link = url.absoluteURL
        }

        // RSS enclosure for media (like featured images)
        if lowerName == "enclosure" && stack.count >= 2 && stack[stack.count - 2] == "item",
           let urlString = attr["url"],
           let type = attr["type"],
           type.hasPrefix("image/"),
           let url = URL(string: urlString, relativeTo: baseURL) {
            currentItem?.featuredImageURL = url.absoluteURL
        }

        if lowerName == "item" && currentItem == nil {
            currentItem = FeedItem(title: "", link: baseURL, contentHTML: nil, author: nil, publishedAt: nil, featuredImageURL: nil)
        }
        if lowerName == "entry" && atomCurrent == nil {
            atomCurrent = FeedItem(title: "", link: baseURL, contentHTML: nil, author: nil, publishedAt: nil, featuredImageURL: nil)
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName qName: String?) {
        let lowerName = name.lowercased()
        let stackCount = stack.count
        defer { _ = stack.popLast() }

        let text = currentText.trimmingCharacters(in: .whitespacesAndNewlines)

        // RSS channel metadata
        if stackCount >= 3 && stack[0] == "rss" && stack[1] == "channel" {
            if stack[2] == "title" && stackCount == 3 {
                rssMeta.title = text
            } else if stackCount == 4 && stack[2] == "image" && stack[3] == "url" {
                rssMeta.thumbnailURL = URL(string: text, relativeTo: baseURL)?.absoluteURL
            }
        }

        // RSS item
        if stackCount >= 2 && stack[stackCount - 2] == "item" {
            switch lowerName {
            case "title":
                currentItem?.title = text
            case "link":
                currentItem?.link = URL(string: text, relativeTo: baseURL) ??  URL(string: text)!
            case "description":
                if currentItem?.featuredImageURL == nil {
                    currentItem?.featuredImageURL = extractImageFromHTML(text)
                }
            case "content:encoded":
                currentItem?.contentHTML = text
                if currentItem?.featuredImageURL == nil {
                    currentItem?.featuredImageURL = extractImageFromHTML(text)
                }
            case "author", "dc:creator":
                currentItem?.author = text
            case "pubdate", "published":
                currentItem?.publishedAt = RFCDate.parse(text)
            case "media:content", "media:thumbnail":
                if currentItem?.featuredImageURL == nil {
                    currentItem?.featuredImageURL = URL(string: text, relativeTo: baseURL)?.absoluteURL
                }
            default:
                break
            }
        }
        
        if lowerName == "item" {
            if let item = currentItem {
                rssItems.append(item)
                // Stop parsing after maxItems
                if rssItems.count >= maxItems {
                    parser.abortParsing()
                }
            }
            currentItem = nil
        }

        // Atom feed metadata
        if stackCount >= 2 && stack[0] == "feed" {
            if stack[1] == "title" && stackCount == 2 {
                atomMeta.title = text
            } else if (stack[1] == "logo" || stack[1] == "icon") && stackCount == 2 {
                atomMeta.thumbnailURL = URL(string: text, relativeTo: baseURL)?.absoluteURL
            }
        }

        // Atom entry
        if stackCount >= 2 && stack[stackCount - 2] == "entry" {
            switch lowerName {
            case "title":
                atomCurrent?.title = text
            case "summary":
                if atomCurrent?.featuredImageURL == nil {
                    atomCurrent?.featuredImageURL = extractImageFromHTML(text)
                }
            case "content":
                atomCurrent?.contentHTML = text
                if atomCurrent?.featuredImageURL == nil {
                    atomCurrent?.featuredImageURL = extractImageFromHTML(text)
                }
            case "author":
                atomCurrent?.author = text
            case "published":
                atomCurrent?.publishedAt = RFCDate.parse(text)
            default:
                break
            }
        }
        
        if lowerName == "entry" {
            if let item = atomCurrent {
                atomItems.append(item)
                // Stop parsing after maxItems
                if atomItems.count >= maxItems {
                    parser.abortParsing()
                }
            }
            atomCurrent = nil
        }

        currentText = ""
    }
    
    // Optimized: Extract first image URL from HTML content
    private func extractImageFromHTML(_ html: String) -> URL? {
        guard let regex = imgRegex else { return nil }
        
        let range = NSRange(html.startIndex..., in: html)
        guard let match = regex.firstMatch(in: html, range: range) else { return nil }
        
        let urlRange = match.range(at: 1)
        guard let swiftRange = Range(urlRange, in: html) else { return nil }
        
        let urlString = String(html[swiftRange])
        return URL(string: urlString, relativeTo: baseURL)?.absoluteURL
    }
    
    // Optimized: Generate favicon URL as fallback
    private func getFaviconURL() -> URL? {
        var components = URLComponents()
        components.scheme = baseURL.scheme
        components.host = baseURL.host
        components.port = baseURL.port
        
        guard let baseHost = components.url else { return nil }
        return URL(string: "/favicon.ico", relativeTo: baseHost)?.absoluteURL
    }
}
