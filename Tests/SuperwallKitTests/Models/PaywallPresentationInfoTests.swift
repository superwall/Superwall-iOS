//
//  PaywallPresentationInfoTests.swift
//  SuperwallKitTests
//
//  Created by Claude on 08/01/2025.
//

import Testing
import Foundation
@testable import SuperwallKit

struct PaywallPresentationInfoTests {
  
  @Test("Initialize with default parameters")
  func initWithDefaultParameters() {
    let presentationInfo = PaywallPresentationInfo(
      style: .modal,
      delay: 100
    )
    
    #expect(presentationInfo.style == .modal)
    #expect(presentationInfo.delay == 100)
  }
  
  @Test("Initialize with drawer parameters")
  func initWithDrawerParameters() {
    let presentationInfo = PaywallPresentationInfo(
      style: .drawer(height: 400.0, cornerRadius: 20.0),
      delay: 200
    )
    
    #expect(presentationInfo.style == .drawer(height: 400.0, cornerRadius: 20.0))
    #expect(presentationInfo.delay == 200)
  }
  
  @Test("Codable with drawer parameters")
  func codableWithDrawerParameters() throws {
    // Test decoding drawer style from JSON with height and corner radius
    let jsonData = """
    {
      "style": {
        "type": "DRAWER",
        "height": 400.5,
        "cornerRadius": 25.0
      },
      "delay": 250
    }
    """.data(using: .utf8)!
    
    let decoder = JSONDecoder()
    let presentationInfo = try decoder.decode(PaywallPresentationInfo.self, from: jsonData)
    
    #expect(presentationInfo.style == .drawer(height: 400.5, cornerRadius: 25.0))
    #expect(presentationInfo.delay == 250)
  }
  
  @Test("Encoding and decoding")
  func encoding() throws {
    let presentationInfo = PaywallPresentationInfo(
      style: .drawer(height: 300.0, cornerRadius: 15.0),
      delay: 300
    )
    
    let encoder = JSONEncoder()
    let jsonData = try encoder.encode(presentationInfo)
    
    let decoder = JSONDecoder()
    let decodedInfo = try decoder.decode(PaywallPresentationInfo.self, from: jsonData)
    
    #expect(decodedInfo.style == .drawer(height: 300.0, cornerRadius: 15.0))
    #expect(decodedInfo.delay == 300)
  }
  
  @Test("Drawer with default parameters")
  func drawerWithDefaultParameters() {
    let presentationInfo = PaywallPresentationInfo(
      style: .drawer(height: 70, cornerRadius: 15),
      delay: 100
    )
    
    #expect(presentationInfo.style == .drawer(height: 70, cornerRadius: 15))
    #expect(presentationInfo.delay == 100)
  }
  
  @Test("Drawer with custom parameters")
  func drawerWithCustomParameters() {
    // Test with custom height and default corner radius
    let customHeight = PaywallPresentationInfo(
      style: .drawer(height: 500.0, cornerRadius: 15.0),
      delay: 100
    )
    
    #expect(customHeight.style == .drawer(height: 500.0, cornerRadius: 15.0))
    
    // Test with default height and custom corner radius
    let customCornerRadius = PaywallPresentationInfo(
      style: .drawer(height: 70.0, cornerRadius: 12.0),
      delay: 100
    )
    
    #expect(customCornerRadius.style == .drawer(height: 70.0, cornerRadius: 12.0))
  }
}
