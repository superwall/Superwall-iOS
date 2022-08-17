//
//  File.swift
//  
//
//  Created by Yusuf Tör on 16/08/2022.
//

@testable import Paywall
import XCTest

final class ConfigLogicTests: XCTestCase {
  func test_chooseVariant_noVariants() {
    do {
      let variant = try ConfigLogic.chooseVariant(from: [])
      XCTFail("Should have produced an error")
    } catch let error as ConfigLogic.TriggerRuleError {
      XCTAssertEqual(error, ConfigLogic.TriggerRuleError.noVariantsFound)
    } catch {
      XCTFail("Should have produced a no variant error")
    }
  }
}
