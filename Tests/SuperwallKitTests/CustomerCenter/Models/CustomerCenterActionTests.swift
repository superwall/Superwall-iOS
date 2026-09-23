import Testing
import Foundation
@testable import SuperwallKit

@Suite("CustomerCenterAction")
struct CustomerCenterActionTests {
  @Test("maps every PathType to the corresponding action")
  func fromPathType() {
    let url = URL(string: "https://a.b")!
    #expect(CustomerCenterAction(pathType: .restore) == .restore)
    #expect(CustomerCenterAction(pathType: .manageSubscription) == .manageSubscription)
    #expect(CustomerCenterAction(pathType: .refund(window: 1)) == .refund)
    #expect(CustomerCenterAction(pathType: .changePlan(productIds: nil)) == .changePlan)
    #expect(CustomerCenterAction(pathType: .contactSupport) == .contactSupport)
    #expect(CustomerCenterAction(pathType: .url(url, openMethod: .external)) == .url(url))
    #expect(CustomerCenterAction(pathType: .custom(identifier: "x")) == .custom(identifier: "x"))
  }

  @Test("analytics name is stable")
  func analyticsName() {
    #expect(CustomerCenterAction.restore.analyticsName == "restore")
    #expect(CustomerCenterAction.manageSubscription.analyticsName == "manage_subscription")
    #expect(CustomerCenterAction.refund.analyticsName == "refund")
    #expect(CustomerCenterAction.changePlan.analyticsName == "change_plan")
    #expect(CustomerCenterAction.contactSupport.analyticsName == "contact_support")
    #expect(CustomerCenterAction.url(URL(string: "https://a.b")!).analyticsName == "url")
    #expect(CustomerCenterAction.custom(identifier: "x").analyticsName == "custom")
  }

  @Test("ObjC path factories round-trip")
  func objcFactories() {
    let path = CustomerCenterConfiguration.Path.url(URL(string: "https://a.b")!, title: "FAQ", id: "faq")
    #expect(path.actionType == .url)
    #expect(path.url?.absoluteString == "https://a.b")
    #expect(path.openMethodObjc == .inApp)
    let custom = CustomerCenterConfiguration.Path.custom(identifier: "delete", id: "c")
    #expect(custom.customIdentifier == "delete")
    let refund = CustomerCenterConfiguration.Path.refund(window: 60, id: "r")
    #expect(refund.refundWindow?.doubleValue == 60)
  }
}
