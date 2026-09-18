//
//  DevServerSettings.swift
//  SuperwallKit
//
//  The settings a `superwall dev` surface declares in its `config.ts`, as the
//  manifest carries them.
//
//  These are the same values `superwall push` stamps on a paywall: the CLI
//  computes them once and serves them here so local code presents the way it
//  will present once pushed. The keys are the push API's, not the static
//  config's, because the dev server stands in for the push — so this type
//  does the translation the backend does in production.
//
//  Settings the manifest carries that iOS has no per-paywall notion of are
//  deliberately absent: `game_controller_enabled` is a SuperwallOption, and
//  `web_checkout_destination` only steers the web build. `on_device_cache` is
//  read by nothing here on purpose — see Paywall.devServer(surface:url:).
//

import Foundation

struct DevServerSettings: Decodable, Equatable {
  let presentationStyle: PaywallPresentationStyle?
  let featureGating: FeatureGatingBehavior?
  let introOfferEligibility: IntroOfferEligibility?
  let isScrollEnabled: Bool?
  let backgroundColorHex: String?
  let darkBackgroundColorHex: String?

  private enum CodingKeys: String, CodingKey {
    case presentationStyle = "presentation_style"
    case featureGating = "feature_gating"
    case introOfferEligibility = "introductory_offer_eligibility"
    case isScrollEnabled = "scroll_enabled"
    case backgroundColorHex = "background_color_hex"
    case darkBackgroundColorHex = "dark_background_color_hex"
  }

  private enum StyleKeys: String, CodingKey {
    case type
    case height
    case width
    case cornerRadius = "corner_radius"
  }

  private enum WireStyle: String {
    case fullscreen = "FULLSCREEN"
    case modal = "MODAL"
    case push = "PUSH"
    case noAnimation = "NO_ANIMATION"
    case drawer = "DRAWER"
    case popup = "POPUP"
  }

  private enum WireGating: String {
    case gated
    case nonGated = "non_gated"
  }

  private enum WireEligibility: String {
    case automatic
    case eligible = "always_eligible"
    case ineligible = "always_ineligible"
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    presentationStyle = try Self.style(in: container)
    let gating = try container.decodeIfPresent(String.self, forKey: .featureGating)
    switch gating.flatMap(WireGating.init(rawValue:)) {
    case .gated:
      featureGating = .gated
    case .nonGated:
      featureGating = .nonGated
    case nil:
      if gating != nil {
        Self.warnUnreadable("feature gating", gating)
      }
      featureGating = nil
    }
    let eligibility = try container.decodeIfPresent(String.self, forKey: .introOfferEligibility)
    switch eligibility.flatMap(WireEligibility.init(rawValue:)) {
    case .automatic:
      introOfferEligibility = .automatic
    case .eligible:
      introOfferEligibility = .eligible
    case .ineligible:
      introOfferEligibility = .ineligible
    case nil:
      if eligibility != nil {
        Self.warnUnreadable("intro offer eligibility", eligibility)
      }
      introOfferEligibility = nil
    }
    isScrollEnabled = try container.decodeIfPresent(Bool.self, forKey: .isScrollEnabled)
    backgroundColorHex = try container.decodeIfPresent(String.self, forKey: .backgroundColorHex)
    darkBackgroundColorHex = try container.decodeIfPresent(
      String.self,
      forKey: .darkBackgroundColorHex
    )
  }

  private static func style(
    in container: KeyedDecodingContainer<CodingKeys>
  ) throws -> PaywallPresentationStyle? {
    guard
      let style = try? container.nestedContainer(keyedBy: StyleKeys.self, forKey: .presentationStyle)
    else {
      return nil
    }

    let type = try style.decodeIfPresent(String.self, forKey: .type)
    let height = try? style.decode(Double.self, forKey: .height)
    let width = try? style.decode(Double.self, forKey: .width)
    let cornerRadius = try? style.decode(Double.self, forKey: .cornerRadius)

    switch type.flatMap(WireStyle.init(rawValue:)) {
    case .fullscreen:
      return .fullscreen
    case .modal:
      return .modal
    case .push:
      return .push
    case .noAnimation:
      return .fullscreenNoAnimation
    case .drawer:
      guard let height = height, let cornerRadius = cornerRadius else {
        return unreadable(type)
      }
      return .drawer(height: height, cornerRadius: cornerRadius)
    case .popup:
      guard let height = height, let width = width, let cornerRadius = cornerRadius else {
        return unreadable(type)
      }
      return .popup(height: height, width: width, cornerRadius: cornerRadius)
    case nil:
      return type == nil ? nil : unreadable(type)
    }
  }

  private static func unreadable(_ type: String?) -> PaywallPresentationStyle? {
    warnUnreadable("presentation style", type)
    return nil
  }

  /// Reports one setting the CLI names in a way this SDK can't read. The CLI
  /// versions separately from the SDK, so a value added after this SDK shipped
  /// costs that setting alone — the rest of the block still stands.
  private static func warnUnreadable(_ name: String, _ value: String?) {
    Logger.debug(
      logLevel: .warn,
      scope: .superwallCore,
      message: "Ignoring a dev server \(name) this SDK can't read "
        + "(\(value ?? "nothing")). The paywall uses its published version's \(name). "
        + "Updating SuperwallKit may fix this."
    )
  }
}
