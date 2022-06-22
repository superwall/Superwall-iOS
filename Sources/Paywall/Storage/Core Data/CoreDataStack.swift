//
//  File.swift
//  
//
//  Created by Yusuf Tör on 17/06/2022.
//

import Foundation
import CoreData

class CoreDataStack {
  static let modelName = "Model"

  static let managedObject: NSManagedObjectModel = {
    guard let modelUrl = Bundle.module.url(
      forResource: "Model",
      withExtension: "momd"
    ) else {
      return .init()
    }
    return NSManagedObjectModel(contentsOf: modelUrl) ?? .init()
  }()

  lazy var persistentContainer: NSPersistentContainer = {
    let container = NSPersistentContainer(
      name: Self.modelName,
      managedObjectModel: Self.managedObject
    )
    container.loadPersistentStores { _, error in
      if let error = error as NSError? {
        print("Unresolved error \(error), \(error.userInfo)")
      }
    }
    return container
  }()

  lazy var backgroundContext: NSManagedObjectContext = {
    let context = persistentContainer.newBackgroundContext()
    // context.automaticallyMergesChangesFromParent = true
    context.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
    return context
  }()

  lazy var mainContext: NSManagedObjectContext = {
    let mainContext = persistentContainer.viewContext
   // mainContext.automaticallyMergesChangesFromParent = true
    mainContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
    return mainContext
  }()

  func fetch<Item: NSFetchRequestResult>(
    _ request: NSFetchRequest<Item>,
    context: NSManagedObjectContext? = nil
  ) -> [Item] {
    let context = context ?? mainContext
    do {
      let items = try context.fetch(request)
      return items
    } catch let error as NSError {
      print("Unresolved error \(error), \(error.userInfo)")
      return []
    }
  }

  func fetch<Item: NSManagedObject>(
    _ request: NSFetchRequest<Item>,
    completion: @escaping ([Item]) -> Void
  ) {
    persistentContainer.performBackgroundTask { context in
      do {
        let items = try context.fetch(request)
        completion(items)
      } catch let error as NSError {
        print("Unresolved error \(error), \(error.userInfo)")
        completion([])
      }
    }
  }

  func saveContext(
    _ context: NSManagedObjectContext,
    completion: (() -> Void)? = nil
  ) {
    context.perform {
      do {
        try context.save()
        completion?()
      } catch let error as NSError {
        print("Unresolved error \(error), \(error.userInfo)")
      }
    }
  }

  func saveContext() {
    backgroundContext.perform {
      do {
        try self.backgroundContext.save()
      } catch let error as NSError {
        print("Unresolved error \(error), \(error.userInfo)")
      }
    }
  }

  func count<T: NSFetchRequestResult>(for fetchRequest: NSFetchRequest<T>) -> Int {
    do {
      let count = try mainContext.count(for: fetchRequest)
      return count
    } catch let error as NSError {
      print("Unresolved error \(error), \(error.userInfo)")
      return 0
    }
  }

  func count<T: NSFetchRequestResult>(
    for fetchRequest: NSFetchRequest<T>,
    completion: @escaping (Int) -> ()
  ) {
    persistentContainer.performBackgroundTask { context in
      do {
        let count = try context.count(for: fetchRequest)
        return completion(count)
      } catch let error as NSError {
        print("Unresolved error \(error), \(error.userInfo)")
        return completion(0)
      }
    }
  }
}
