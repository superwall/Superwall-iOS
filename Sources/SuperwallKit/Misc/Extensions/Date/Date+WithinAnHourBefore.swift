//
//  File.swift
//  
//
//  Created by Yusuf Tör on 19/09/2023.
//

import Foundation

extension Date {
  func isWithinAnHourBefore(_ date: Date) -> Bool {
    let oneHourBefore = date.addingTimeInterval(-3600)
    return compare(oneHourBefore) == .orderedDescending
  }
}
