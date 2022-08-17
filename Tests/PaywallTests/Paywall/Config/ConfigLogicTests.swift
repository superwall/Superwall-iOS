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
      let _ = try ConfigLogic.chooseVariant(from: [])
      XCTFail("Should have produced an error")
    } catch let error as ConfigLogic.TriggerRuleError {
      XCTAssertEqual(error, ConfigLogic.TriggerRuleError.noVariantsFound)
    } catch {
      XCTFail("Should have produced a no variant error")
    }
  }

  func test_chooseVariant_zeroPercentageSumVariants() {
    do {
      let _ = try ConfigLogic.chooseVariant(from: [
        .stub()
        .setting(\.percentage, to: 0)
      ])
      XCTFail("Should have produced an error")
    } catch let error as ConfigLogic.TriggerRuleError {
      XCTAssertEqual(error, ConfigLogic.TriggerRuleError.invalidState)
    } catch {
      XCTFail("Should have produced a no variant error")
    }
  }

  func test_chooseVariant_oneActiveVariant_chooseFirst() {
    do {
      let options: [VariantOption] = [
        .stub()
        .setting(\.percentage, to: 100),
        .stub()
        .setting(\.percentage, to: 0),
        .stub()
        .setting(\.percentage, to: 0)
      ]
      let variant = try ConfigLogic.chooseVariant(from: options)
      XCTAssertEqual(options.first!.toVariant(), variant)
    } catch {
      XCTFail("Should have produced a no variant error")
    }
  }

  func test_chooseVariant_99PercentSumVariants_chooseLast() {
    do {
      let options: [VariantOption] = [
        .stub()
        .setting(\.percentage, to: 33),
        .stub()
        .setting(\.percentage, to: 33),
        .stub()
        .setting(\.percentage, to: 33)
      ]
      let variant = try ConfigLogic.chooseVariant(
        from: options,
        randomiser: { range in
          XCTAssertEqual(range, 0..<99)
          return 98
        }
      )
      XCTAssertEqual(options.last!.toVariant(), variant)
    } catch {
      XCTFail("Should have produced a no variant error")
    }
  }

  func test_chooseVariant_99PercentSumVariants_chooseMiddle() {
    do {
      let options: [VariantOption] = [
        .stub()
        .setting(\.percentage, to: 33),
        .stub()
        .setting(\.percentage, to: 33),
        .stub()
        .setting(\.percentage, to: 33)
      ]
      let variant = try ConfigLogic.chooseVariant(
        from: options,
        randomiser: { range in
          XCTAssertEqual(range, 0..<99)
          return 65
        }
      )
      XCTAssertEqual(options[1].toVariant(), variant)
    } catch {
      XCTFail("Should have produced a no variant error")
    }
  }

  func test_chooseVariant_99PercentSumVariants_chooseFirst() {
    do {
      let options: [VariantOption] = [
        .stub()
        .setting(\.percentage, to: 33),
        .stub()
        .setting(\.percentage, to: 33),
        .stub()
        .setting(\.percentage, to: 33)
      ]
      let variant = try ConfigLogic.chooseVariant(
        from: options,
        randomiser: { range in
          XCTAssertEqual(range, 0..<99)
          return 0
        }
      )
      XCTAssertEqual(options.first!.toVariant(), variant)
    } catch {
      XCTFail("Should have produced a no variant error")
    }
  }
}
