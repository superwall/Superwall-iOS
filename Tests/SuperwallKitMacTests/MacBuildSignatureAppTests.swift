// swiftlint:disable all
#if os(macOS)
import Foundation
import Security
import Testing
@testable import SuperwallKit

struct MacBuildSignatureAppTests {
  /// A copy of a small system tool, signed to run locally as Xcode signs a
  /// build that has no development team.
  private func makeLocallySignedTool(entitlements: [String: Any]) throws -> URL {
    let folder = FileManager.default.temporaryDirectory
      .appendingPathComponent("MacBuildSignatureAppTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let tool = folder.appendingPathComponent("tool")
    try FileManager.default.copyItem(at: URL(fileURLWithPath: "/usr/bin/true"), to: tool)
    let entitlementsFile = folder.appendingPathComponent("tool.entitlements")
    let data = try PropertyListSerialization.data(
      fromPropertyList: entitlements,
      format: .xml,
      options: 0
    )
    try data.write(to: entitlementsFile)

    let codesign = Process()
    codesign.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
    codesign.arguments = [
      "--force", "--sign", "-", "--entitlements", entitlementsFile.path, tool.path
    ]
    codesign.standardOutput = FileHandle.nullDevice
    codesign.standardError = FileHandle.nullDevice
    try codesign.run()
    codesign.waitUntilExit()
    try #require(codesign.terminationStatus == 0)
    return tool
  }

  @Test(arguments: MacBuildSignature.SandboxRequirement.allCases)
  func requirementIsOneTheSystemUnderstands(_ sandboxRequirement: MacBuildSignature.SandboxRequirement) {
    var requirement: SecRequirement?
    let status = SecRequirementCreateWithString(
      sandboxRequirement.rawValue as CFString,
      [],
      &requirement
    )
    #expect(status == errSecSuccess)
    #expect(requirement != nil)
  }

  @Test
  func locallySignedBuildThatAllowsTheDebuggerIsSandbox() throws {
    let tool = try makeLocallySignedTool(entitlements: [MacBuildSignature.debuggerEntitlement: true])
    defer { try? FileManager.default.removeItem(at: tool.deletingLastPathComponent()) }
    #expect(MacBuildSignature.isSandbox(codeAt: tool))
  }

  @Test
  func locallySignedBuildThatRefusesTheDebuggerIsNotSandbox() throws {
    let tool = try makeLocallySignedTool(entitlements: [MacBuildSignature.debuggerEntitlement: false])
    defer { try? FileManager.default.removeItem(at: tool.deletingLastPathComponent()) }
    #expect(!MacBuildSignature.isSandbox(codeAt: tool))
  }

  @Test
  func locallySignedBuildWithoutTheDebuggerEntitlementIsNotSandbox() throws {
    let tool = try makeLocallySignedTool(entitlements: [:])
    defer { try? FileManager.default.removeItem(at: tool.deletingLastPathComponent()) }
    #expect(!MacBuildSignature.isSandbox(codeAt: tool))
  }

  /// Apple signs the apps that come with macOS with neither a TestFlight nor a
  /// development certificate, as it does a released app.
  @Test
  func appSignedForReleaseIsNotSandbox() {
    let calculator = URL(fileURLWithPath: "/System/Applications/Calculator.app")
    #expect(!MacBuildSignature.isSandbox(codeAt: calculator))
  }

  @Test
  func runningCodeIsReadAsItsExecutableOnDiskIs() throws {
    let executable = try #require(Bundle.main.executableURL)
    #expect(MacBuildSignature.isSandbox == MacBuildSignature.isSandbox(codeAt: executable))
  }

  @Test
  func codeThatDoesNotExistIsNotSandbox() {
    let missing = FileManager.default.temporaryDirectory
      .appendingPathComponent("\(UUID().uuidString).app")
    #expect(!MacBuildSignature.isSandbox(codeAt: missing))
  }
}
#endif
