import XCTest
@testable import Paywall

final class PaywallTests: XCTestCase {
	func testProductNumber() {
		
		// This is an example of a functional test case.
		// Use XCTAssert and related functions to verify your tests produce the correct
		// results.
		
		let a = ProductNumber(value: 0.82, format: .currency, locale: .autoupdatingCurrent)
		XCTAssertEqual(a.value, 0.82)
		XCTAssertEqual(a.prettyValue, 0.80)
		XCTAssertEqual(a.formatted, "$0.82")
		XCTAssertEqual(a.pretty, "$0.80")
		
		let b = ProductNumber(value: 0.82, format: .percent, locale: .autoupdatingCurrent)
		XCTAssertEqual(b.value, 0.82)
		XCTAssertEqual(b.prettyValue, 0.80)
		XCTAssertEqual(b.formatted, "82%")
		XCTAssertEqual(b.pretty, "80%")
		
		let c = ProductNumber(value: 0.82, format: .number, locale: .autoupdatingCurrent)
		XCTAssertEqual(c.value, 0.82)
		XCTAssertEqual(c.prettyValue, 0.80)
		XCTAssertEqual(c.formatted, "0.82")
		XCTAssertEqual(c.pretty, "0.8")
		
	}
}


