//
//  DevServerPreviewTests.swift
//  SuperwallKitTests
//

import Foundation
import Testing
@testable import SuperwallKit

@Suite(.serialized)
struct DevServerPreviewTests {
  private func options(
    devServer: SuperwallOptions.DevServer? = .default
  ) -> SuperwallOptions {
    let options = SuperwallOptions()
    options.devServer = devServer
    return options
  }

  // MARK: - Deep link parsing

  @Test("Parses the base and surface from a dev link")
  func outcome_parsesBaseAndSurface() throws {
    let url = try #require(
      URL(string: "myapp://?superwall_dev=http://localhost:6100&superwall_dev_surface=pro")
    )
    let outcome = try #require(DevServerPreview.outcomeForDeepLink(url: url))
    #expect(outcome.base.absoluteString == "http://localhost:6100")
    #expect(outcome.surfaceId == "pro")
  }

  // MARK: - Trusted bases

  @Test(
    "Hosts superwall dev can print are trusted",
    arguments: [
      "http://localhost:6100",
      "http://127.0.0.1:6100",
      "http://[::1]:6100",
      "http://yusufs-macbook.local:6100",
      "http://10.0.1.5:6100",
      "http://172.20.10.2:6100",
      "http://192.168.1.10:6100",
      "http://169.254.5.5:6100"
    ]
  )
  func trustedBase_privateHosts(base: String) throws {
    let url = try #require(URL(string: base))
    #expect(DevServerPreview.isTrustedBase(url, devServerURL: nil))
  }

  @Test(
    "Arbitrary internet hosts are not trusted",
    arguments: [
      "https://evil.example.com",
      "http://8.8.8.8:6100",
      "http://172.32.0.1:6100",
      "http://10.0.0.1.evil.example.com:6100"
    ]
  )
  func trustedBase_publicHosts(base: String) throws {
    let url = try #require(URL(string: base))
    #expect(!DevServerPreview.isTrustedBase(url, devServerURL: nil))
  }

  @Test("The developer-supplied devServerURL is trusted wherever it points")
  func trustedBase_matchingDevServerURL() throws {
    let devServerURL = try #require(URL(string: "https://tunnel.example.com:8443"))
    let matching = try #require(URL(string: "https://tunnel.example.com:8443"))
    let otherPort = try #require(URL(string: "https://tunnel.example.com:9999"))
    #expect(DevServerPreview.isTrustedBase(matching, devServerURL: devServerURL))
    #expect(!DevServerPreview.isTrustedBase(otherPort, devServerURL: devServerURL))
  }

  // MARK: - canHandle

  @Test("A dev link is not Superwall's when no dev server is set")
  func canHandle_devServerOff() throws {
    let url = try #require(URL(string: "myapp://?superwall_dev=http://localhost:6100"))
    #expect(!DevServerPreview.canHandle(url: url, options: options(devServer: nil)))
  }

  @Test("A dev link pointing at a local host is Superwall's when a dev server is set")
  func canHandle_devServerOnLocalHost() throws {
    DevMode.isSandboxEnvironment = { true }
    defer { DevMode.isSandboxEnvironment = { DeviceHelper.isSandboxEnvironment } }

    let url = try #require(URL(string: "myapp://?superwall_dev=http://localhost:6100"))
    #expect(DevServerPreview.canHandle(url: url, options: options()))
  }

  @Test("A dev link pointing at an internet host is refused even with a dev server set")
  func canHandle_devServerOnPublicHost() throws {
    DevMode.isSandboxEnvironment = { true }
    defer { DevMode.isSandboxEnvironment = { DeviceHelper.isSandboxEnvironment } }

    let url = try #require(URL(string: "myapp://?superwall_dev=https://evil.example.com"))
    #expect(!DevServerPreview.canHandle(url: url, options: options()))
  }
}
