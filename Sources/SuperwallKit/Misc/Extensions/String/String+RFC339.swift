//
//  File.swift
//  
//
//  Created by Yusuf Tör on 14/12/2022.
//

import Foundation

extension String {
  func rfc3339date() -> Date? {
    let date = rfc3339DateFormatter.date(from: self)
    return date
  }
}

var rfc3339DateFormatter: ISO8601DateFormatter = {
  let formatter = ISO8601DateFormatter()
  formatter.formatOptions = .withInternetDateTime
  formatter.timeZone = TimeZone(abbreviation: "UTC")
  return formatter
}()
