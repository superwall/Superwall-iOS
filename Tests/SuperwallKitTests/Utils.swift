//
//  File.swift
//  
//
//  Created by Brian Anglin on 2/19/22.
//

import Foundation

struct TestError: Error {
  let message: String

  init(_ message: String) {
    self.message = message
  }

  var localizedDescription: String {
    return message
  }
}
