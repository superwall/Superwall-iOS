//
//  PaywallViewControllerDrawerTests.swift
//  SuperwallKitTests
//
//  Created by Claude on 08/01/2025.
//

import Testing
import Foundation
@testable import SuperwallKit

struct PaywallViewControllerDrawerTests {
  @Test("Drawer presentation info with default values")
  func drawerPresentationInfoDefaultValues() {
    // Create presentation info with drawer style using default values
    let presentation = PaywallPresentationInfo(
      style: .drawer(height: 70, cornerRadius: 15),
      delay: 0
    )
    
    // Verify default values are used
    #expect(presentation.style == .drawer(height: 70, cornerRadius: 15))
  }
  
  @Test("Drawer presentation info with custom values")
  func drawerPresentationInfoCustomValues() {
    // Create presentation info with custom drawer settings
    let presentation = PaywallPresentationInfo(
      style: .drawer(height: 400.0, cornerRadius: 20.0),
      delay: 0
    )
    
    // Verify custom values are set correctly
    #expect(presentation.style == .drawer(height: 400.0, cornerRadius: 20.0))
  }
  
  @Test("Drawer presentation info with boundary values")
  func drawerPresentationInfoBoundaryValues() {
    // Test with minimum values
    let minPresentation = PaywallPresentationInfo(
      style: .drawer(height: 50.0, cornerRadius: 0.0),
      delay: 0
    )
    
    #expect(minPresentation.style == .drawer(height: 50.0, cornerRadius: 0.0))
    
    // Test with maximum values
    let maxPresentation = PaywallPresentationInfo(
      style: .drawer(height: 1000.0, cornerRadius: 50.0),
      delay: 0
    )
    
    #expect(maxPresentation.style == .drawer(height: 1000.0, cornerRadius: 50.0))
  }
  
  @Test("Drawer presentation info with mixed values")
  func drawerPresentationInfoMixedValues() {
    // Test with custom height and default corner radius
    let customHeight = PaywallPresentationInfo(
      style: .drawer(height: 300.0, cornerRadius: 15.0),
      delay: 0
    )
    
    #expect(customHeight.style == .drawer(height: 300.0, cornerRadius: 15.0))
    
    // Test with default height and custom corner radius
    let customCornerRadius = PaywallPresentationInfo(
      style: .drawer(height: 70.0, cornerRadius: 25.0),
      delay: 0
    )
    
    #expect(customCornerRadius.style == .drawer(height: 70.0, cornerRadius: 25.0))
  }
  
  @Test("PaywallPresentationStyle to Objective-C conversion")
  func paywallPresentationStyleToObjcConversion() {
    // Test conversion to Objective-C enum
    let drawer = PaywallPresentationStyle.drawer(height: 400.0, cornerRadius: 20.0)
    let objcStyle = drawer.toObjcStyle()
    
    #expect(objcStyle == .drawer)
    
    // Test other styles
    #expect(PaywallPresentationStyle.modal.toObjcStyle() == .modal)
    #expect(PaywallPresentationStyle.fullscreen.toObjcStyle() == .fullscreen)
    #expect(PaywallPresentationStyle.push.toObjcStyle() == .push)
    #expect(PaywallPresentationStyle.none.toObjcStyle() == .none)
  }
  
  @Test("PaywallPresentationStyle extract drawer parameters")
  func paywallPresentationStyleExtractDrawerParameters() {
    // Test extracting height and corner radius
    let drawer = PaywallPresentationStyle.drawer(height: 500.0, cornerRadius: 25.0)
    
    #expect(drawer.drawerHeight?.doubleValue == 500.0)
    #expect(drawer.drawerCornerRadius?.doubleValue == 25.0)
    
    // Test with zero values
    let zeroDrawer = PaywallPresentationStyle.drawer(height: 0.0, cornerRadius: 0.0)
    #expect(zeroDrawer.drawerHeight?.doubleValue == 0.0)
    #expect(zeroDrawer.drawerCornerRadius?.doubleValue == 0.0)
    
    // Test with non-drawer style
    let modal = PaywallPresentationStyle.modal
    #expect(modal.drawerHeight == nil)
    #expect(modal.drawerCornerRadius == nil)
  }
  
  @Test("PaywallPresentationStyleObjc to Swift conversion")
  func paywallPresentationStyleObjcToSwiftConversion() {
    // Test conversion from Objective-C to Swift enum
    let objcDrawer = PaywallPresentationStyleObjc.drawer
    let swiftStyle = objcDrawer.toSwift(
      height: NSNumber(value: 300.0),
      cornerRadius: NSNumber(value: 15.0)
    )
    
    #expect(swiftStyle == .drawer(height: 300.0, cornerRadius: 15.0))
    
    // Test without parameters (uses defaults)
    let swiftStyleDefaults = objcDrawer.toSwift()
    #expect(swiftStyleDefaults == .drawer(height: 70.0, cornerRadius: 15.0))
    
    // Test other styles
    #expect(PaywallPresentationStyleObjc.modal.toSwift() == .modal)
    #expect(PaywallPresentationStyleObjc.fullscreen.toSwift() == .fullscreen)
    #expect(PaywallPresentationStyleObjc.push.toSwift() == .push)
    #expect(PaywallPresentationStyleObjc.none.toSwift() == .none)
  }
}
