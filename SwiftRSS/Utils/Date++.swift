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
