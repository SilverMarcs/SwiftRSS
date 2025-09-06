import Foundation
import SwiftData
import UniformTypeIdentifiers

struct OPMLFeedEntry {
    var title: String?
    var xmlURL: URL
    var htmlURL: URL?
}

enum OPMLParseError: Error {
    case invalid
    case parsingFailed
}

class OPMLImporter: NSObject, XMLParserDelegate {
    private var items: [OPMLFeedEntry] = []

    static func parse(data: Data, baseURL: URL? = nil) throws -> [OPMLFeedEntry] {
        let importer = OPMLImporter()
        let parser = XMLParser(data: data)
        parser.delegate = importer
        
        guard parser.parse() else {
            throw parser.parserError ?? OPMLParseError.parsingFailed
        }
        
        return importer.items
    }

    // MARK: - XMLParserDelegate
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        
        if elementName.lowercased() == "outline" {
            // Check if this outline has an xmlUrl (indicating it's a feed)
            if let xmlUrlString = attributeDict["xmlUrl"],
               let xmlUrl = URL(string: xmlUrlString) {
                
                let title = attributeDict["title"] ?? attributeDict["text"]
                let htmlUrl = attributeDict["htmlUrl"].flatMap { URL(string: $0) }
                
                let entry = OPMLFeedEntry(
                    title: title,
                    xmlURL: xmlUrl,
                    htmlURL: htmlUrl
                )
                
                items.append(entry)
            }
        }
    }
    
    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        print("OPML Parse Error: \(parseError)")
    }
}

extension UTType {
    static var opml: UTType {
        UTType(importedAs: "org.opml.opml")
    }
}

@MainActor
func importOPML(data: Data, context: ModelContext) async throws {
    print("Starting OPML import...")
    
    do {
        let entries = try OPMLImporter.parse(data: data)
        print("Found \(entries.count) feed entries in OPML")
        
        var successCount = 0
        var failureCount = 0
        
        for entry in entries {
            print("Importing feed: \(entry.title ?? "Untitled") - \(entry.xmlURL)")
            
            do {
                _ = try await FeedService.subscribe(url: entry.xmlURL, context: context)
                successCount += 1
                print("✅ Successfully imported: \(entry.title ?? entry.xmlURL.absoluteString)")
            } catch {
                failureCount += 1
                print("❌ Failed to import \(entry.title ?? entry.xmlURL.absoluteString): \(error)")
            }
        }
        
        try context.save()
        print("OPML import completed. Success: \(successCount), Failures: \(failureCount)")
        
    } catch {
        print("Failed to parse OPML: \(error)")
        throw error
    }
}
