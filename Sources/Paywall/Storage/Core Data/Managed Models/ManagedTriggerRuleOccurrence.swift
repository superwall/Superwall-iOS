//
//  File.swift
//  
//
//  Created by Yusuf Tör on 05/07/2022.
//

import Foundation
import CoreData

final class ManagedTriggerRuleOccurence: NSManagedObject {
  @nonobjc
  class func fetchRequest() -> NSFetchRequest<ManagedTriggerRuleOccurence> {
    return NSFetchRequest<ManagedTriggerRuleOccurence>(entityName: "TriggerRuleOccurence")
  }

  @NSManaged var createdAt: Date
  @NSManaged var occurrenceKey: String

  init(
    context: NSManagedObjectContext,
    createdAt: Date,
    occurrenceKey: String
  ) {
    let entity = NSEntityDescription.entity(
      forEntityName: "EventData",
      in: context
    )!
    super.init(entity: entity, insertInto: context)

    self.createdAt = createdAt
    self.occurrenceKey = occurrenceKey
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
