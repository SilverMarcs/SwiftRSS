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
    
    private static let rfc1123: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(secondsFromGMT: 0)
        df.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        return df
    }()

    static func parse(_ s: String) -> Date? {
        if let d = iso8601.date(from: s) { return d }
        if let d = rfc1123.date(from: s) { return d }
        return nil
    }
}
