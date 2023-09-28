//
//  File.swift
//  
//
//  Created by Yusuf Tör on 28/09/2023.
//

import Foundation

/// Serially executes tasks added to it.
final class SerialTaskManager {
  private var taskQueue: Queue<() async -> Void> = Queue()
  private var dispatchQueue = DispatchQueue(label: "com.superwall.serial-task-queue")

  func addTask(_ task: @escaping () async -> Void) {
    dispatchQueue.async { [weak self] in
      guard let self = self else {
        return
      }

      // Add the task to the queue
      self.taskQueue.enqueue(task)

      // If there's only one task in the queue, start executing it
      if self.taskQueue.count == 1 {
        self.executeNextTask()
      }
    }
  }

  private func executeNextTask() {
    dispatchQueue.async { [weak self] in
      guard let self = self else {
        return
      }
      // Check if there are tasks in the queue
      if taskQueue.isEmpty {
        return
      }

      // Get the next task from the queue
      guard let nextTask = taskQueue.dequeue() else {
        return
      }

      Task {
        await nextTask()
        // After the task completes, recursively execute the next task
        self.executeNextTask()
      }
    }
  }
}
