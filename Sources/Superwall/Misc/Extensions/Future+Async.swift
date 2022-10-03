//
//  File.swift
//  
//
//  Created by Yusuf Tör on 23/09/2022.
//

import Combine

extension Future where Failure == Error {
  convenience init(operation: @escaping () async throws -> Output) {
    self.init { promise in
      Task {
        do {
          let output = try await operation()
          promise(.success(output))
        } catch {
          promise(.failure(error))
        }
      }
    }
  }
}
