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
            // Today - show time only
            return self.formatted(date: .omitted, time: .shortened)
        } else {
            // Other days - show date
            return self.formatted(.dateTime.day().month(.abbreviated))
        }
    }
}

enum DateParsers {
    // ISO8601DateFormatter is thread-safe per Apple docs; cache and reuse it.
    static let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [
            .withInternetDateTime,
            .withFractionalSeconds,
            .withColonSeparatorInTime,
            .withColonSeparatorInTimeZone
        ]
        return f
    }()
}

// Simple thread-safety wrapper for non-thread-safe formatters like DateFormatter
final class ThreadSafeFormatter<F> {
    private let queue = DispatchQueue(label: "fmt.\(F.self)")
    let formatter: F
    init(make: () -> F) { self.formatter = make() }
    func sync<T>(_ block: (F) -> T) -> T {
        queue.sync { block(formatter) }
    }
}

// Flexible RSS/HTTP date parsing (RFC 1123, RFC 850, asctime, common variants)
enum RFCDate {
    static let rfc1123 = ThreadSafeFormatter<DateFormatter> {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(secondsFromGMT: 0)
        df.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z" // RFC 1123
        return df
    }
    static let rfc1123NoSec = ThreadSafeFormatter<DateFormatter> {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(secondsFromGMT: 0)
        df.dateFormat = "EEE, dd MMM yyyy HH:mm Z" // common variant without seconds
        return df
    }
    static let rfc850 = ThreadSafeFormatter<DateFormatter> {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(secondsFromGMT: 0)
        df.dateFormat = "EEEE, dd-MMM-yy HH:mm:ss Z" // RFC 850
        return df
    }
    static let asctime = ThreadSafeFormatter<DateFormatter> {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(secondsFromGMT: 0)
        df.dateFormat = "EEE MMM d HH:mm:ss yyyy" // asctime
        return df
    }

    static func parse(_ s: String) -> Date? {
        if let d = DateParsers.iso8601.date(from: s) { return d }
        if let d = rfc1123.sync({ $0.date(from: s) }) { return d }
        if let d = rfc1123NoSec.sync({ $0.date(from: s) }) { return d }
        if let d = rfc850.sync({ $0.date(from: s) }) { return d }
        if let d = asctime.sync({ $0.date(from: s) }) { return d }
        return nil
    }
}
