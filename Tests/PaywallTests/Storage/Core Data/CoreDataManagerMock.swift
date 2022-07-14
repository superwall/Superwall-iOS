//
//  File.swift
//  
//
//  Created by Yusuf Tör on 14/07/2022.
//

import CoreData
@testable import Paywall

@available(iOS 14.0, *)
final class CoreDataManagerMock: CoreDataManager {
  let internalDataStack: CoreDataStack

  override init(coreDataStack: CoreDataStack = CoreDataStack()) {
    self.internalDataStack = coreDataStack
    super.init(coreDataStack: coreDataStack)
  }

  func countAllEvents() -> Int {
    let fetchRequest = ManagedEventData.fetchRequest()
    return internalDataStack.count(for: fetchRequest)
  }
}
