//
//  OPMLParser.swift
//  SwiftRSS
//
//  Created by Zabir Raihan on 20/10/2025.
//

import Foundation

class OPMLParser: NSObject, XMLParserDelegate {
    private var urls: [URL] = []
    private var currentUrl: String?
    
    static func parse(data: Data) -> [URL] {
        let opmlParser = OPMLParser()
        let parser = XMLParser(data: data)
        parser.delegate = opmlParser
        parser.parse()
        return opmlParser.urls
    }
    
    // MARK: - XMLParserDelegate
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        if elementName == "outline", let type = attributeDict["type"], type == "rss" {
            currentUrl = attributeDict["xmlUrl"]
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "outline",
           let urlString = currentUrl,
           let url = URL(string: urlString) {
            let secureUrl = url.scheme?.lowercased() == "http"
                ? URL(string: urlString.replacingOccurrences(of: "http://", with: "https://")) ?? url
                : url
            
            urls.append(secureUrl)
            currentUrl = nil
        }
    }
}
