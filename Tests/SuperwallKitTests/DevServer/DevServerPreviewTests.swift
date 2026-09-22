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

  private func surface(id: String, products: [String: String]?) throws -> DevServerSurface {
    let productsJSON = products.map { dict in
      "{" + dict.map { "\"\($0.key)\": \"\($0.value)\"" }.sorted().joined(separator: ",") + "}"
    } ?? "null"
    let json = """
    {"kind": "paywall", "id": "\(id)", "url": "/preview/paywall/\(id)", "products": \(productsJSON)}
    """
    return try JSONDecoder().decode(DevServerSurface.self, from: Data(json.utf8))
  }

  // MARK: - Resolving a dev: surface

  @Test("A dev: surface is resolved from the manifest the server serves now")
  func resolveSurface_prefersTheFreshManifest() throws {
    // The debugger opened while config.ts declared one product. It has since
    // been edited to declare another, and the server's manifest says so.
    let base = try #require(URL(string: "http://localhost:6100"))
    let stale = try surface(id: "pro", products: ["primary": "old_product"])
    let edited = try surface(id: "pro", products: ["primary": "new_product"])

    let resolved = try #require(
      DevServerPreview.resolveSurface(
        previewIdentifier: "dev:pro",
        fresh: DevServerLocation(base: base, manifest: DevServerManifest(surfaces: [edited])),
        snapshot: (base: base, surfaces: [stale])
      )
    )
    #expect(resolved.surface == edited)
    #expect(resolved.url.absoluteString == "http://localhost:6100/preview/paywall/pro")
  }

  @Test("A dev: surface falls back to the debugger's snapshot when the server is unreachable")
  func resolveSurface_fallsBackToTheSnapshot() throws {
    let base = try #require(URL(string: "http://localhost:6100"))
    let snapshotSurface = try surface(id: "pro", products: ["primary": "old_product"])

    let resolved = try #require(
      DevServerPreview.resolveSurface(
        previewIdentifier: "dev:pro",
        fresh: nil,
        snapshot: (base: base, surfaces: [snapshotSurface])
      )
    )
    #expect(resolved.surface == snapshotSurface)
    #expect(resolved.url.absoluteString == "http://localhost:6100/preview/paywall/pro")
  }

  @Test("A dev: surface the server no longer lists is not resolved from the snapshot")
  func resolveSurface_freshManifestWithoutTheSurface_returnsNil() throws {
    let base = try #require(URL(string: "http://localhost:6100"))
    let removed = try surface(id: "pro", products: nil)
    let other = try surface(id: "winback", products: nil)

    let resolved = DevServerPreview.resolveSurface(
      previewIdentifier: "dev:pro",
      fresh: DevServerLocation(base: base, manifest: DevServerManifest(surfaces: [other])),
      snapshot: (base: base, surfaces: [removed])
    )
    #expect(resolved == nil)
  }

  @Test("Without a snapshot or a server there is nothing to resolve")
  func resolveSurface_nothingToResolve() {
    let resolved = DevServerPreview.resolveSurface(
      previewIdentifier: "dev:pro",
      fresh: nil,
      snapshot: nil
    )
    #expect(resolved == nil)
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
