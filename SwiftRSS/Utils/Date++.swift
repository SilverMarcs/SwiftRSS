//
//  Date++.swift
//  SwiftRSS
//
//  Created by Zabir Raihan on 06/09/2025.
//

import Foundation

extension Date {
    var publishedFormat: String {
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDate(self, inSameDayAs: now) {
            return self.formatted(date: .omitted, time: .shortened)
        } else {
            return self.formatted(.dateTime.day().month(.abbreviated))
        }
    }
}

enum RFCDate {
    private static let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    
    private static let iso8601NoFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
    
    private static let rfc1123: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(secondsFromGMT: 0)
        df.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        return df
    }()
    
    private static let rfc1123NoDay: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(secondsFromGMT: 0)
        df.dateFormat = "dd MMM yyyy HH:mm:ss Z"
        return df
    }()
    
    private static let rfc1123NoSeconds: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(secondsFromGMT: 0)
        df.dateFormat = "EEE, dd MMM yyyy HH:mm Z"
        return df
    }()
    
    // Common alternative formats
    private static let iso8601Basic: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(secondsFromGMT: 0)
        df.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        return df
    }()

    static func parse(_ s: String) -> Date? {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 1. RFC1123 - Most common in RSS feeds (pubDate)
        if let d = rfc1123.date(from: trimmed) { return d }
        
        // 2. ISO8601 with fractional seconds - Common in Atom feeds
        if let d = iso8601.date(from: trimmed) { return d }
        
        // 3. ISO8601 without fractional seconds - Also common in Atom
        if let d = iso8601NoFractional.date(from: trimmed) { return d }
        
        // 4. Auto ISO8601 - Catches many variants
        let autoISO = ISO8601DateFormatter()
        if let d = autoISO.date(from: trimmed) { return d }
        
        // 5. ISO8601 basic format - Less common but still used
        if let d = iso8601Basic.date(from: trimmed) { return d }
        
        // 6. RFC1123 without seconds - Rare variant
        if let d = rfc1123NoSeconds.date(from: trimmed) { return d }
        
        // 7. RFC1123 without day name - Very rare
        if let d = rfc1123NoDay.date(from: trimmed) { return d }
        
        return nil
    }
}
