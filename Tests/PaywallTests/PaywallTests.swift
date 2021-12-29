import XCTest
@testable import Paywall

final class PaywallTests: XCTestCase {
	func testProductNumber() {
		
		// This is an example of a functional test case.
		// Use XCTAssert and related functions to verify your tests produce the correct
		// results.
		
//		let a = SWProductNumberGroup(value: 0.82, format: .currency, locale: .autoupdatingCurrent)
//		XCTAssertEqual(a.value, 0.82)
//		XCTAssertEqual(a.prettyValue, 0.79)
//		XCTAssertEqual(a.formatted, "$0.82")
//		XCTAssertEqual(a.pretty, "$0.79")
//
//		let b = SWProductNumberGroup(value: 0.82, format: .percent, locale: .autoupdatingCurrent)
//		XCTAssertEqual(b.value, 0.82)
//		XCTAssertEqual(b.prettyValue, 0.80)
//		XCTAssertEqual(b.formatted, "82%")
//		XCTAssertEqual(b.pretty, "80%")
//
//		let c = SWProductNumberGroup(value: 0.82, format: .number, locale: .autoupdatingCurrent)
//		XCTAssertEqual(c.value, 0.82)
//		XCTAssertEqual(c.prettyValue, 0.80)
//		XCTAssertEqual(c.formatted, "0.82")
//		XCTAssertEqual(c.pretty, "0.8")
//
//		let d = SWProductNumberGroup(value: 4.23, format: .currency, locale: .autoupdatingCurrent)
//		XCTAssertEqual(d.value, 4.23)
//		XCTAssertEqual(d.prettyValue, 4.19)
//		XCTAssertEqual(d.formatted, "$4.23")
//		XCTAssertEqual(d.pretty, "$4.19")
//
//		let e = SWProductNumberGroup(value: 4.23, format: .percent, locale: .autoupdatingCurrent)
//		XCTAssertEqual(e.value, 4.23)
//		XCTAssertEqual(e.prettyValue, 4.25)
//		XCTAssertEqual(e.formatted, "423%")
//		XCTAssertEqual(e.pretty, "425%")
//
//		let f = SWProductNumberGroup(value: 4.23, format: .number, locale: .autoupdatingCurrent)
//		XCTAssertEqual(f.value, 4.23)
//		XCTAssertEqual(f.prettyValue, 4.25)
//		XCTAssertEqual(f.formatted, "4.23")
//		XCTAssertEqual(f.pretty, "4.25")
//
//		let g = SWProductNumberGroup(value: 89.987, format: .currency, locale: .autoupdatingCurrent)
//		XCTAssertEqual(g.value, 89.987)
//		XCTAssertEqual(g.prettyValue, 89.99)
//		XCTAssertEqual(g.formatted, "$89.99")
//		XCTAssertEqual(g.pretty, "$89.99")
//
//		let h = SWProductNumberGroup(value: 89.987, format: .percent, locale: .autoupdatingCurrent)
//		XCTAssertEqual(h.value, 89.987)
//		XCTAssertEqual(h.prettyValue, 90.0)
//		XCTAssertEqual(h.formatted, "8,999%")
//		XCTAssertEqual(h.pretty, "9,000%")
//
//		let i = SWProductNumberGroup(value: 89.987, format: .number, locale: .autoupdatingCurrent)
//		XCTAssertEqual(i.value, 89.987)
//		XCTAssertEqual(i.prettyValue, 90.0)
//		XCTAssertEqual(i.formatted, "89.99")
//		XCTAssertEqual(i.pretty, "90")
//
	}
	
	func testDateComponents() {
//		let dateComponents: DateComponents
//
//		switch subscriptionPeriod.unit {
//		case .day: dateComponents = DateComponents(day: subscriptionPeriod.numberOfUnits)
//		case .week: dateComponents = DateComponents(weekOfMonth: subscriptionPeriod.numberOfUnits)
//		case .month: dateComponents = DateComponents(month: subscriptionPeriod.numberOfUnits)
//		case .year: dateComponents = DateComponents(year: subscriptionPeriod.numberOfUnits)
//		@unknown default:
//			dateComponents = DateComponents(month: subscriptionPeriod.numberOfUnits)
//		}

		let f = DateComponentsFormatter()
		f.unitsStyle = .full
		f.allowedUnits = [.year]
		f.allowsFractionalUnits = true
		
		
		print(f.string(from: DateComponents(day: 390)))

		
	}
}


