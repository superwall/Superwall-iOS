//
//  File.swift
//  
//
//  Created by Yusuf Tör on 14/07/2022.
//

import CoreData
@testable import SuperwallKit

final class CoreDataManagerMock: CoreDataManager {
  let internalDataStack: CoreDataStack

  override init(
    coreDataStack: CoreDataStack = CoreDataStack(),
    lifecycle: AppLifecycle = .live
  ) {
    self.internalDataStack = coreDataStack
    super.init(coreDataStack: coreDataStack, lifecycle: lifecycle)
  }

  func countAllEvents() async -> Int {
    let fetchRequest = ManagedEventData.fetchRequest()

    return await internalDataStack.count(for: fetchRequest)
  }
}
