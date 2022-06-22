//
//  File.swift
//  
//
//  Created by Yusuf Tör on 16/06/2022.
//
// swiftlint:disable force_unwrapping

import Foundation
import CoreData

final class ManagedEventData: NSManagedObject {
  @nonobjc
  class func fetchRequest() -> NSFetchRequest<ManagedEventData> {
    return NSFetchRequest<ManagedEventData>(entityName: "EventData")
  }

  @NSManaged var id: String
  @NSManaged var createdAt: Date
  @NSManaged var name: String
  @NSManaged var parameters: Data

  init(
    context: NSManagedObjectContext,
    id: String,
    createdAt: Date,
    name: String,
    parameters: Data
  ) {
    let entity = NSEntityDescription.entity(
      forEntityName: "EventData",
      in: context
    )!
    super.init(entity: entity, insertInto: context)

    self.id = id
    self.createdAt = createdAt
    self.name = name
    self.parameters = parameters
  }

  @objc override private init(
    entity: NSEntityDescription,
    insertInto context: NSManagedObjectContext?
  ) {
    super.init(entity: entity, insertInto: context)
  }

  @available(*, unavailable)
  init() {
    fatalError("\(#function) not implemented")
  }

  @available(*, unavailable)
  convenience init(context: NSManagedObjectContext) {
    fatalError("\(#function) not implemented")
  }
}
