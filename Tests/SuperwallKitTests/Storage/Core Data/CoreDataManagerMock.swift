//
//  File.swift
//  
//
//  Created by Yusuf Tör on 14/07/2022.
//

import CoreData
@testable import SuperwallKit

@available(iOS 14.0, *)
final class CoreDataManagerMock: CoreDataManager {
  let internalDataStack: CoreDataStack

  override init(coreDataStack: CoreDataStack = CoreDataStack()) {
    self.internalDataStack = coreDataStack
    super.init(coreDataStack: coreDataStack)
  }

  func countAllEvents() async -> Int {
    let fetchRequest = ManagedPlacementData.fetchRequest()

    return await withCheckedContinuation { continuation in
      internalDataStack.count(for: fetchRequest) { count in
        continuation.resume(returning: count)
      }
    }
  }
}
