//
//  File.swift
//  
//
//  Created by Yusuf Tör on 27/09/2022.
//

import Foundation
import Combine

extension Publisher {
  /// `flatMap` run on the main thread.
  func mainMap<T>(
    _ operation: @escaping @MainActor (Output) throws -> T
  ) -> Publishers.FlatMap<Future<T, Error>, Self> {
    flatMap { value in
      Future { promise in
        Task {
          try await MainActor.run {
            let output = try operation(value)
            promise(.success(output))
          }
        }
      }
    }
  }

  /// An async version of `flatMap`.
  func asyncMap<T>(
    _ operation: @escaping (Output) async throws -> T
  ) -> Publishers.FlatMap<Future<T, Error>, Self> {
    flatMap { value in
      Future {
        try await operation(value)
      }
    }
  }
}
