//
//  CoreDataMock.swift
//  
//
//  Created by Yusuf Tör on 17/06/2022.
//

import XCTest
import CoreData
@testable import Paywall

final class CoreDataStackMock: CoreDataStack {
  override init() {
    super.init()
    let container = NSPersistentContainer(
      name: CoreDataStack.modelName,
      managedObjectModel: CoreDataStack.managedObject
    )

    let persistentStoreDescription = NSPersistentStoreDescription()
    persistentStoreDescription.type = NSSQLiteStoreType
    container.persistentStoreDescriptions = [persistentStoreDescription]

    container.loadPersistentStores { _, error in
      if let error = error as NSError? {
        fatalError("Unresolved error \(error), \(error.userInfo)")
      }
    }

    persistentContainer = container
  }

  func deleteAllEntities(named entityName: String) {
    let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: entityName)
    let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)

    do {
      try persistentContainer.persistentStoreCoordinator.execute(deleteRequest, with: mainContext)
      print("Deleted entities")
    } catch let error as NSError {
      print("Error deleting!", error)
    }
  }
}

