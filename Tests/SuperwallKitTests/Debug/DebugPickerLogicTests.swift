//
//  DebugPickerLogicTests.swift
//  SuperwallKitTests
//

import XCTest
@testable import SuperwallKit

final class DebugPickerLogicTests: XCTestCase {
  func test_splitsLocalSurfacesAndPublishedPaywallsIntoSections() {
    let sections = DebugPickerLogic.sections(
      localSurfaceIds: ["chatgpt-plus", "pro"],
      publishedNames: ["Winback", "Onboarding"],
      selectedLocalId: "pro",
      selectedPublishedIndex: nil
    )
    XCTAssertEqual(sections.map { $0.title }, [
      DebugPickerLogic.localTitle,
      DebugPickerLogic.publishedTitle
    ])
    XCTAssertEqual(sections[0].rows.map { $0.title }, ["chatgpt-plus", "pro"])
    XCTAssertEqual(sections[0].rows.map { $0.kind }, [.local(index: 0), .local(index: 1)])
    XCTAssertEqual(sections[1].rows.map { $0.kind }, [.published(index: 0), .published(index: 1)])
  }

  func test_marksTheShowingPaywall() {
    let local = DebugPickerLogic.sections(
      localSurfaceIds: ["pro"],
      publishedNames: ["Winback"],
      selectedLocalId: "pro",
      selectedPublishedIndex: 0
    )
    XCTAssertTrue(local[0].rows[0].isSelected)
    // a local surface is on screen, so no published row is marked
    XCTAssertFalse(local[1].rows[0].isSelected)

    let published = DebugPickerLogic.sections(
      localSurfaceIds: [],
      publishedNames: ["Winback", "Onboarding"],
      selectedLocalId: nil,
      selectedPublishedIndex: 1
    )
    XCTAssertEqual(published[0].rows.filter { $0.isSelected }.map { $0.title }, ["Onboarding"])
  }

  func test_searchFiltersBothSectionsAndDropsEmptyOnes() {
    let sections = DebugPickerLogic.sections(
      localSurfaceIds: ["chatgpt-plus", "pro"],
      publishedNames: ["Winback"],
      selectedLocalId: nil,
      selectedPublishedIndex: nil,
      query: "  CHAT "
    )
    XCTAssertEqual(sections.count, 1)
    XCTAssertEqual(sections[0].title, DebugPickerLogic.localTitle)
    XCTAssertEqual(sections[0].rows.map { $0.title }, ["chatgpt-plus"])
    // the row still points at its original index, not the filtered one
    XCTAssertEqual(sections[0].rows[0].kind, .local(index: 0))
  }

  func test_keepsIndicesStableWhenSearchHidesEarlierRows() {
    let sections = DebugPickerLogic.sections(
      localSurfaceIds: ["alpha", "beta", "gamma"],
      publishedNames: [],
      selectedLocalId: nil,
      selectedPublishedIndex: nil,
      query: "gamma"
    )
    XCTAssertEqual(sections[0].rows.map { $0.kind }, [.local(index: 2)])
  }

  func test_omitsASectionWithNothingInIt() {
    let sections = DebugPickerLogic.sections(
      localSurfaceIds: [],
      publishedNames: ["Winback"],
      selectedLocalId: nil,
      selectedPublishedIndex: 0
    )
    XCTAssertEqual(sections.map { $0.title }, [DebugPickerLogic.publishedTitle])
  }
}
