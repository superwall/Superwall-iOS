//
//  File.swift
//  
//
//  Created by Yusuf Tör on 05/07/2022.
//
// swiftlint:disable force_unwrapping

import Foundation
import CoreData

final class ManagedTriggerRuleOccurrence: NSManagedObject {
  private static let entityName = "TriggerRuleOccurrence"
  @nonobjc
  class func fetchRequest() -> NSFetchRequest<ManagedTriggerRuleOccurrence> {
    return NSFetchRequest<ManagedTriggerRuleOccurrence>(entityName: entityName)
  }

  @NSManaged var createdAt: Date
  @NSManaged var occurrenceKey: String

  init?(
    context: NSManagedObjectContext,
    createdAt: Date,
    occurrenceKey: String
  ) {
    guard let entity = NSEntityDescription.entity(
      forEntityName: Self.entityName,
      in: context
    ) else {
      return nil
    }
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
