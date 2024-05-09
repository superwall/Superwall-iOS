//
//  File.swift
//  
//
//  Created by Yusuf Tör on 08/05/2024.
//

import Foundation

protocol TaskExecutor {
  associatedtype Input: Identifiable
  associatedtype Output
  func perform(using input: Input) async throws -> Output
}
