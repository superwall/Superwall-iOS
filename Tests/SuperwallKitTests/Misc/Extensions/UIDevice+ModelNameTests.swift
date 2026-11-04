//
//  UIDevice+ModelNameTests.swift
//  SuperwallKitTests
//
//  Created by Superwall on 21/10/2026.
//

import Testing
import UIKit
@testable import SuperwallKit

struct UIDeviceModelNameTests {
  @Test("Reads the model a simulator emulates")
  func readsSimulatorModel() {
    let environment = ["SIMULATOR_MODEL_IDENTIFIER": "iPhone19,4"]
    #expect(UIDevice.simulatorModelName(in: environment) == "iPhone19,4")
  }

  @Test("Is nil without a simulator model")
  func nilWithoutSimulatorModel() {
    #expect(UIDevice.simulatorModelName(in: [:]) == nil)
    #expect(UIDevice.simulatorModelName(in: ["SIMULATOR_MODEL_IDENTIFIER": ""]) == nil)
  }

  @Test("Reports the emulated model when running in a simulator")
  func reportsEmulatedModelInSimulator() {
    #if targetEnvironment(simulator)
    #expect(UIDevice.simulatorModelName == ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"])
    #expect(UIDevice.simulatorModelName != nil)
    #else
    #expect(UIDevice.simulatorModelName == nil)
    #endif
  }

  @Test("Sends the simulator model to the paywall, and leaves it out on a real device")
  func templateDevice() async {
    let dependencyContainer = DependencyContainer(cache: CacheMock())
    let deviceHelper: DeviceHelper = dependencyContainer.deviceHelper

    deviceHelper.simulatorModel = "iPhone19,4"
    let simulator = await deviceHelper.getTemplateDevice()
    #expect(simulator["simulatorModel"] as? String == "iPhone19,4")

    deviceHelper.simulatorModel = nil
    let device = await deviceHelper.getTemplateDevice()
    #expect(device.keys.contains("simulatorModel") == false)
    #expect(device["deviceModel"] as? String == deviceHelper.model)
    withExtendedLifetime(dependencyContainer) {}
  }
}
