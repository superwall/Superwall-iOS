//
//  RequestCoalleser.swift
//  PaywallArchiveBuilder
//
//  Created by Brian Anglin on 4/26/24.
//

import Foundation

public actor RequestCoalescence<Input: Identifiable, Output> {
  private var tasks: [Int: [(Output) -> Void]] = [:]
  
  public init() {}
  
  public func get(input: Input, request: @escaping (Input) async -> Output) async -> Output {
    if tasks[input.id.hashValue] != nil {
      // If there's already a task in progress, wait for it to finish
      return await withCheckedContinuation { continuation in
        appendCompletion(for: input.id.hashValue) { output in
          continuation.resume(returning: output)
        }
      }
    } else {
      // Start a new task if one isn't already in progress
      tasks[input.id.hashValue] = []
      let output = await request(input)
      completeTasks(for: input.id.hashValue, with: output)
      return output
    }
  }
  
  private func appendCompletion(for hashValue: Int, completion: @escaping (Output) -> Void) {
    tasks[hashValue]?.append(completion)
  }
  
  private func completeTasks(for hashValue: Int, with output: Output) {
    tasks[hashValue]?.forEach { $0(output) }
    tasks[hashValue] = nil
  }
}
