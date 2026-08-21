//
//  CustomerCenterScreenState.swift
//
//
//  Created by Jordan Morgan on 20/08/2026.
//

import Foundation

enum CustomerCenterScreenState: Equatable { case loading, management, noPurchases }
enum CustomerCenterRestoreState: Equatable { case idle, restoring, restored, notFound }

enum CustomerCenterSheet: Identifiable, Equatable {
  case survey(pathId: String)
  case manageSubscriptions(groupId: String?)
  case changePlan(groupId: String?, productIds: [String]?)
  case refund(transactionId: UInt64, productId: String)
  case safari(URL)
  case noMailApp(email: String)

  var id: String {
    switch self {
    case .survey(let id): return "survey:\(id)"
    case .manageSubscriptions(let groupId): return "manage:\(groupId ?? "")"
    case let .changePlan(groupId, productIds):
      return "change:\(groupId ?? ""):\(productIds?.joined(separator: ",") ?? "")"
    case .refund(let transactionId, _): return "refund:\(transactionId)"
    case .safari(let url): return "safari:\(url.absoluteString)"
    case .noMailApp: return "nomail"
    }
  }
}

struct CustomerCenterCallbacks {
  var shouldRestore: ((@escaping (Bool) -> Void) -> Void)?
  var didSelectAction: ((CustomerCenterAction, SubscriptionTransaction?) -> Void)?
  var didCompleteSurvey: ((_ surveyId: String, _ optionId: String, _ action: CustomerCenterAction) -> Void)?
  var didCompleteRefund: ((_ productId: String, _ status: CustomerCenterRefundStatus) -> Void)?
  var didDismiss: (() -> Void)?
}
