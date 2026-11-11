//
//  UIApplication+ActiveWindowTests.swift
//  SuperwallKitTests
//
//  Created by Superwall on 11/11/2026.
//

import Testing
import UIKit
@testable import SuperwallKit

@MainActor
struct UIApplicationActiveWindowTests {
  struct Scene: ForegroundSceneCandidate, Equatable {
    let name: String
    let activationState: UIScene.ActivationState
    var hasActiveAppearance = false
  }

  @Test("Picks the active scene with focus when several are active")
  func picksFocusedSceneAmongActiveOnes() {
    let scenes = [
      Scene(name: "left", activationState: .foregroundActive),
      Scene(name: "right", activationState: .foregroundActive, hasActiveAppearance: true)
    ]
    #expect(scenes.foregroundScene()?.name == "right")
    #expect(scenes.reversed().foregroundScene()?.name == "right")
  }

  @Test("Picks the first active scene when none has focus")
  func picksFirstActiveSceneWithoutFocus() {
    let scenes = [
      Scene(name: "left", activationState: .foregroundActive),
      Scene(name: "right", activationState: .foregroundActive)
    ]
    #expect(scenes.foregroundScene()?.name == "left")
  }

  @Test("Picks an active scene before an inactive one that looks active")
  func picksActiveSceneBeforeInactiveOne() {
    let scenes = [
      Scene(name: "inactive", activationState: .foregroundInactive, hasActiveAppearance: true),
      Scene(name: "active", activationState: .foregroundActive)
    ]
    #expect(scenes.foregroundScene()?.name == "active")
  }

  @Test("Picks the inactive scene with focus when no scene is active")
  func picksFocusedInactiveScene() {
    let scenes = [
      Scene(name: "background", activationState: .background, hasActiveAppearance: true),
      Scene(name: "old", activationState: .foregroundInactive),
      Scene(name: "new", activationState: .foregroundInactive, hasActiveAppearance: true)
    ]
    #expect(scenes.foregroundScene()?.name == "new")
  }

  @Test("Is nil when no scene is in the foreground")
  func nilWithoutForegroundScene() {
    let scenes = [
      Scene(name: "background", activationState: .background, hasActiveAppearance: true),
      Scene(name: "unattached", activationState: .unattached)
    ]
    #expect(scenes.foregroundScene() == nil)
    #expect([Scene]().foregroundScene() == nil)
  }
}
