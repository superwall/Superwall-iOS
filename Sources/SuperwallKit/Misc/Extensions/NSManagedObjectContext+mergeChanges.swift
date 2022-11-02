//
//  File.swift
//  
//
//  Created by Yusuf Tör on 14/07/2022.
//

import CoreData

extension NSManagedObjectContext {
  /// Executes the given `NSBatchDeleteRequest` and directly merges the changes to bring the given managed object context up to date.
  ///
  /// - Parameter batchDeleteRequest: The `NSBatchDeleteRequest` to execute.
  /// - Throws: An error if anything went wrong executing the batch deletion.
  func executeAndMergeChanges(using batchDeleteRequest: NSBatchDeleteRequest) throws {
    batchDeleteRequest.resultType = .resultTypeObjectIDs
    let result = try execute(batchDeleteRequest) as? NSBatchDeleteResult
    let changes: [AnyHashable: Any] = [
      NSDeletedObjectsKey: result?.result as? [NSManagedObjectID] ?? []
    ]
    NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [self])
  }
}
