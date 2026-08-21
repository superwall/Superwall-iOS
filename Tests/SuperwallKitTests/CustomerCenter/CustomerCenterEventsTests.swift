import Testing
import Foundation
@testable import SuperwallKit

@Suite("CustomerCenter events")
struct CustomerCenterEventsTests {
  @Test("descriptions and objc mirrors")
  func descriptions() {
    #expect(SuperwallEvent.customerCenterOpen(screen: "management").description == "customerCenter_open")
    #expect(SuperwallEvent.customerCenterClose.description == "customerCenter_close")
    #expect(SuperwallEvent.customerCenterAction(action: .restore, pathId: "p", productId: nil).description == "customerCenter_action")
    #expect(SuperwallEvent.customerCenterSurveyResponse(surveyId: "s", optionId: "o", action: .manageSubscription, pathId: "p", productId: "x").description == "customerCenter_surveyResponse")
    #expect(SuperwallEvent.customerCenterRefundRequest(productId: "x", status: .success).description == "customerCenter_refundRequest")
    #expect(SuperwallEventObjc(event: .customerCenterClose) == .customerCenterClose)
  }

  @Test("open event carries the screen and how the Customer Center was presented")
  func openParameters() async {
    let sheet = InternalSuperwallEvent.CustomerCenterOpen(screen: "management", presentation: "sheet")
    let sheetParams = await sheet.getSuperwallParameters()
    #expect(sheetParams["screen"] as? String == "management")
    #expect(sheetParams["presentation"] as? String == "sheet")

    let embedded = InternalSuperwallEvent.CustomerCenterOpen(screen: "no_active", presentation: "embedded")
    let embeddedParams = await embedded.getSuperwallParameters()
    #expect(embeddedParams["screen"] as? String == "no_active")
    #expect(embeddedParams["presentation"] as? String == "embedded")
  }

  @Test("trackable parameters")
  func parameters() async {
    let action = InternalSuperwallEvent.CustomerCenterAction(action: .custom(identifier: "del"), pathId: "p1", productId: "prod")
    let params = await action.getSuperwallParameters()
    #expect(params["action"] as? String == "custom")
    #expect(params["custom_identifier"] as? String == "del")
    #expect(params["path_id"] as? String == "p1")
    #expect(params["product_id"] as? String == "prod")

    let survey = InternalSuperwallEvent.CustomerCenterSurveyResponse(surveyId: "s", optionId: "o", action: .manageSubscription, pathId: "p", productId: nil)
    let sp = await survey.getSuperwallParameters()
    #expect(sp["survey_id"] as? String == "s")
    #expect(sp["option_id"] as? String == "o")
    #expect(sp["action"] as? String == "manage_subscription")
    #expect(sp["product_id"] == nil)

    let refund = InternalSuperwallEvent.CustomerCenterRefundRequest(productId: "x", status: .userCancelled)
    let rp = await refund.getSuperwallParameters()
    #expect(rp["status"] as? String == "user_cancelled")
  }
}
