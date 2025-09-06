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
    }

    func parseRSS2() throws -> (FeedMeta, [FeedItem]) {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return (rssMeta, rssItems)
    }

    func parseAtom() throws -> (FeedMeta, [FeedItem]) {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return (atomMeta, atomItems)
    }

    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName qName: String?, attributes attr: [String : String] = [:]) {
        stack.append(name.lowercased())
        currentText = ""

        // Atom <link href="">
        if stack.suffix(2) == ["entry","link"], let href = attr["href"], let url = URL(string: href, relativeTo: baseURL) {
            atomCurrent?.link = url.absoluteURL
        }

        // RSS enclosure is handled in text or attributes
        if stack.suffix(2) == ["channel","link"] { /* text later */ }
        if stack.suffix(2) == ["channel","image"] { /* ignore */ }

        if stack.suffix(1) == ["item"] && currentItem == nil {
            currentItem = FeedItem(title: "", link: baseURL, summary: nil, contentHTML: nil, author: nil, publishedAt: nil, updatedAt: nil, thumbnailURL: nil)
        }
        if stack.suffix(1) == ["entry"] && atomCurrent == nil {
            atomCurrent = FeedItem(title: "", link: baseURL, summary: nil, contentHTML: nil, author: nil, publishedAt: nil, updatedAt: nil, thumbnailURL: nil)
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

        // RSS item
        if path.suffix(2) == ["item","title"] { currentItem?.title = text }
        if path.suffix(2) == ["item","link"], let u = URL(string: text, relativeTo: baseURL) { currentItem?.link = u.absoluteURL }
        if path.suffix(2) == ["item","description"] { currentItem?.summary = text }
        if path.suffix(2) == ["item","content:encoded"] { currentItem?.contentHTML = text }
        if path.suffix(2) == ["item","author"] { currentItem?.author = text }
        if path.suffix(2) == ["item","dc:creator"] { currentItem?.author = text }
        if path.suffix(2) == ["item","pubdate"] || path.suffix(2) == ["item","published"] {
            currentItem?.publishedAt = ISO8601DateFormatter().date(from: text) ?? DateFormatter.rfc822.date(from: text)
        }
        if lower == "item" {
            if let item = currentItem {
                rssItems.append(item)
            }
            currentItem = nil
        }

        // Atom feed
        if path.suffix(2) == ["feed","title"] { atomMeta.title = text }

        // Atom entry
        if path.suffix(2) == ["entry","title"] { atomCurrent?.title = text }
        if path.suffix(2) == ["entry","summary"] { atomCurrent?.summary = text }
        if path.suffix(2) == ["entry","content"] { atomCurrent?.contentHTML = text }
        if path.suffix(2) == ["entry","author"] { atomCurrent?.author = text }
        if path.suffix(2) == ["entry","published"] { atomCurrent?.publishedAt = ISO8601DateFormatter().date(from: text) }
        if path.suffix(2) == ["entry","updated"] { atomCurrent?.updatedAt = ISO8601DateFormatter().date(from: text) }
        if lower == "entry" {
            if let item = atomCurrent {
                atomItems.append(item)
            }
            atomCurrent = nil
        }

        currentText = ""
    }
}

extension DateFormatter {
    static let rfc822: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(secondsFromGMT: 0)
        df.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        return df
    }()
}
