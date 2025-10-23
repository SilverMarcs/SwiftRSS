import Foundation
import Fuzi

/// Protocol for feed format parsers
protocol FeedParser {
    /// Parse feed items from XML document
    func parseItems(from document: XMLDocument) throws -> [FeedItem]
    
    /// Parse feed metadata from XML document
    func parseMeta(from document: XMLDocument) -> FeedMeta
}
