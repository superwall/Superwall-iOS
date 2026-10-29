//
//  CustomStoreCheckoutHandler.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 29/10/2026.
//

import Foundation

/// Runs the custom store checkouts that a paywall handles itself, without a
/// `PurchaseController`, finishing each step through the `TransactionManager`.
final class CustomStoreCheckoutHandler {
  private let transactionManager: TransactionManager
  private let storeKitManager: StoreKitManager
  private let factory: PurchasedTransactionsFactory

  init(
    transactionManager: TransactionManager,
    storeKitManager: StoreKitManager,
    factory: PurchasedTransactionsFactory
  ) {
    self.transactionManager = transactionManager
    self.storeKitManager = storeKitManager
    self.factory = factory
  }

  /// Handles a step of a custom store checkout that the paywall runs itself.
  ///
  /// Each step finishes like its `PurchaseController` counterpart for a custom
  /// product: `transaction_start`, `transaction_complete` with a
  /// ``CustomStoreTransaction``, the post-purchase redeem and the
  /// dismissal, `transaction_abandon` or `transaction_fail` with the purchase
  /// failure alert. The `PurchaseController` isn't called.
  ///
  /// Steps for products that aren't custom products are ignored, and so are
  /// steps other than a complete that arrive while the purchasing coordinator
  /// holds a purchase that isn't a custom store checkout, so they can't take
  /// over its state. A paid checkout must always complete: a complete takes
  /// over that purchase, and a start or a complete replaces another custom
  /// store checkout the coordinator still holds, abandoning it. An abandon of
  /// a checkout that isn't in progress is ignored, as when it already completed
  /// or ended with its paywall, and so is a fail while another checkout is in
  /// progress or once the paywall began to close. `Superwall` runs the steps
  /// one at a time and never during a purchase started from a paywall.
  // swiftlint:disable:next function_body_length
  func handle(
    _ checkout: CustomStoreCheckout,
    paywallViewController: PaywallViewController
  ) async {
    let productId = checkout.productId
    guard
      let product = await storeKitManager.product(withId: productId),
      product.isCustomProduct
    else {
      Logger.debug(
        logLevel: .error,
        scope: .transactions,
        message: "Ignoring a custom store checkout of \"\(productId)\": "
          + "it isn't a custom product of this paywall.",
        info: ["checkout": checkout]
      )
      return
    }

    // The checkout is over after any step but its start.
    let checkoutProductId: String?
    if case .start = checkout {
      checkoutProductId = productId
    } else {
      checkoutProductId = nil
    }

    guard var ownership = await ownershipOfHandledStep(
      checkout,
      of: product,
      paywallViewController: paywallViewController
    ) else {
      return
    }

    if checkoutProductId == nil, checkout.closesBrowser {
      // Close the checkout's in-app browser, if it's still open. The paywall's
      // dismissal would wait on it, and closing it from here isn't tracked as
      // an abandoned Stripe checkout. A purchase may start meanwhile, so look
      // at the purchasing coordinator again afterwards.
      await paywallViewController.closeSafari()
      guard let ownershipAfterClose = await ownershipOfHandledStep(
        checkout,
        of: product,
        paywallViewController: paywallViewController
      ) else {
        return
      }
      ownership = ownershipAfterClose
    }

    if ownership == .otherPurchase {
      // Only a complete gets here. The buyer paid, so it's handled while the
      // other purchase is set aside.
      Logger.debug(
        logLevel: .warn,
        scope: .transactions,
        message: "Completing a custom store checkout of \"\(productId)\" "
          + "while another purchase is in progress.",
        info: ["checkout": checkout]
      )
    }

    if ownership == .otherCustomStoreCheckout,
      let staleSource = await factory.makePurchasingCoordinator().source {
      // The page has moved on from a stale checkout of its own, so only another
      // paywall's page is told of its abandon.
      var isOnOtherPaywall = true
      if case let .internal(_, stalePaywall, _) = staleSource {
        isOnOtherPaywall = stalePaywall !== paywallViewController
      }
      await abandonCustomStoreCheckout(from: staleSource, notifiesPage: isOnOtherPaywall)
      ownership = .none
    }

    await MainActor.run {
      paywallViewController.customStoreCheckoutProductId = checkoutProductId
      if !checkout.closesBrowser, paywallViewController.isSafariVCPresented {
        // The checkout already ended, so the buyer closing its sheet later abandons nothing.
        paywallViewController.isCustomStoreCheckoutSheetLeftOpen = true
      }
    }

    // A checkout's last steps can arrive after its paywall began to close.
    let isPaywallOpen = await MainActor.run {
      paywallViewController.isActive && !paywallViewController.isClosing
    }

    switch checkout {
    case .start(_, let customTransactionId):
      await transactionManager.prepareToPurchase(
        product: product,
        // Whether the purchase closes the paywall is only known when it completes.
        purchaseSource: .internal(productId, paywallViewController, false),
        customStoreCheckoutTransactionId: customTransactionId
      )
    case let .complete(_, customTransactionId, shouldDismiss):
      product.customTransactionId = customTransactionId
      let coordinator = factory.makePurchasingCoordinator()
      let otherPurchase = ownership == .otherPurchase ? await coordinator.setAsidePurchase() : nil
      // The purchase still counts, but a closing paywall isn't dismissed again.
      let source = await resumeCustomStoreCheckout(
        of: product,
        productId: productId,
        paywallViewController: paywallViewController,
        isInProgress: ownership == .thisCheckout,
        shouldDismiss: shouldDismiss && isPaywallOpen
      )
      await transactionManager.handle(result: .purchased, state: .purchasing(source))
      if let otherPurchase {
        await coordinator.restore(otherPurchase)
      }
    case .abandon(_, let reason):
      _ = await resumeCustomStoreCheckout(
        of: product,
        productId: productId,
        paywallViewController: paywallViewController,
        isInProgress: ownership == .thisCheckout
      )
      await transactionManager.trackCancelled(canTriggerPaywall: reason.isBuyersChoice && isPaywallOpen)
      await factory.makePurchasingCoordinator().reset()
    case .fail(_, let message):
      if !isPaywallOpen {
        // Closing the paywall ends its checkout, so there's no failure to report.
        Logger.debug(
          logLevel: .warn,
          scope: .transactions,
          message: "Ignoring a custom store checkout of \"\(productId)\": its paywall closed.",
          info: ["checkout": checkout]
        )
        return
      }
      let source = await resumeCustomStoreCheckout(
        of: product,
        productId: productId,
        paywallViewController: paywallViewController,
        isInProgress: ownership == .thisCheckout
      )
      await transactionManager.handle(
        result: .failed(PurchaseError.customStoreCheckoutFailed(message)),
        state: .purchasing(source)
      )
    }
  }

  /// Ends the custom store checkout that `paywallViewController` started, if it's
  /// still in progress, tracking `transaction_abandon`.
  ///
  /// The paywall calls this when it's dismissed or presented again, after any
  /// checkout steps it already handed over. Its page can't report how that
  /// checkout ends any more, and the checkout would keep holding the purchasing
  /// coordinator, where observer mode would skip App Store purchases because of
  /// it. A completion that arrives afterwards is still handled, as a checkout
  /// without a start.
  func endCheckout(of paywallViewController: PaywallViewController) async {
    await MainActor.run {
      paywallViewController.customStoreCheckoutProductId = nil
    }
    guard let source = await customStoreCheckoutSource(of: paywallViewController) else {
      return
    }
    await abandonCustomStoreCheckout(from: source)
  }

  /// Whether the purchasing coordinator holds a custom store checkout that
  /// `paywallViewController` started.
  func isRunningCheckout(of paywallViewController: PaywallViewController) async -> Bool {
    return await customStoreCheckoutSource(of: paywallViewController) != nil
  }

  /// The source of the custom store checkout that the purchasing coordinator
  /// holds for `paywallViewController`, if it holds one.
  private func customStoreCheckoutSource(
    of paywallViewController: PaywallViewController
  ) async -> PurchaseSource? {
    let coordinator = factory.makePurchasingCoordinator()
    guard
      await coordinator.isCustomStoreCheckout,
      let source = await coordinator.source,
      case let .internal(_, checkoutPaywall, _) = source,
      checkoutPaywall === paywallViewController
    else {
      return nil
    }
    return source
  }

  /// Tracks `transaction_abandon` for the custom store checkout the purchasing
  /// coordinator holds, started from `source`, and releases the coordinator.
  ///
  /// The SDK concludes this abandon, not the buyer, so it doesn't present a
  /// paywall: one would appear after the buyer closed theirs, or close the
  /// paywall they're buying from.
  ///
  /// - Parameter notifiesPage: Whether the paywall's page is told of the abandon.
  private func abandonCustomStoreCheckout(
    from source: PurchaseSource,
    notifiesPage: Bool = true
  ) async {
    if case let .internal(_, checkoutPaywall, _) = source {
      await MainActor.run {
        checkoutPaywall.customStoreCheckoutProductId = nil
      }
    }
    await transactionManager.trackCancelled(canTriggerPaywall: false, notifiesPage: notifiesPage)
    await factory.makePurchasingCoordinator().reset()
  }

  private func customStoreCheckoutOwnership(
    of product: StoreProduct,
    paywallViewController: PaywallViewController
  ) async -> CustomStoreCheckoutOwnership {
    let coordinator = factory.makePurchasingCoordinator()
    guard let source = await coordinator.source else {
      return .none
    }
    guard await coordinator.isCustomStoreCheckout else {
      return .otherPurchase
    }
    if case let .internal(_, checkoutPaywall, _) = source,
      checkoutPaywall === paywallViewController,
      await coordinator.product?.productIdentifier == product.productIdentifier {
      return .thisCheckout
    }
    return .otherCustomStoreCheckout
  }

  /// Who holds the purchasing coordinator, if `checkout` can be handled.
  ///
  /// Logs and returns `nil` when the step must be ignored. The checkout is over
  /// after an ignored step that isn't a start, so the paywall stops tracking it
  /// unless the coordinator still holds a checkout of that paywall.
  private func ownershipOfHandledStep(
    _ checkout: CustomStoreCheckout,
    of product: StoreProduct,
    paywallViewController: PaywallViewController
  ) async -> CustomStoreCheckoutOwnership? {
    let ownership = await customStoreCheckoutOwnership(
      of: product,
      paywallViewController: paywallViewController
    )
    guard let reason = ownership.reasonToIgnore(checkout) else {
      return ownership
    }
    Logger.debug(
      logLevel: .warn,
      scope: .transactions,
      message: "Ignoring a custom store checkout of \"\(product.productIdentifier)\": \(reason).",
      info: ["checkout": checkout]
    )
    if case .start = checkout {
      return nil
    }
    if await customStoreCheckoutSource(of: paywallViewController) == nil {
      await MainActor.run {
        paywallViewController.customStoreCheckoutProductId = nil
      }
    }
    return nil
  }

  /// Points the purchasing coordinator at a custom store checkout that has
  /// ended, so its outcome is handled like a `PurchaseController` result.
  ///
  /// A checkout the coordinator holds from its start keeps its start time and
  /// free trial availability. Otherwise, such as when the start never arrived,
  /// the checkout begins now.
  private func resumeCustomStoreCheckout(
    of product: StoreProduct,
    productId: String,
    paywallViewController: PaywallViewController,
    isInProgress: Bool,
    shouldDismiss: Bool = false
  ) async -> PurchaseSource {
    let coordinator = factory.makePurchasingCoordinator()
    let source = PurchaseSource.internal(productId, paywallViewController, shouldDismiss)
    if isInProgress {
      await coordinator.setSource(source)
    } else {
      await coordinator.beginPurchase(
        of: product,
        source: source,
        isFreeTrialAvailable: await transactionManager.isFreeTrialAvailable(for: product),
        isCustomStoreCheckout: true
      )
    }
    return source
  }
}

/// Who holds the purchasing coordinator when a custom store checkout step arrives.
private enum CustomStoreCheckoutOwnership {
  /// The coordinator holds no purchase.
  case none
  /// The coordinator holds this checkout, from its start.
  case thisCheckout
  /// The coordinator holds a custom store checkout of another product or paywall.
  case otherCustomStoreCheckout
  /// The coordinator holds a purchase that isn't a custom store checkout.
  case otherPurchase

  /// Why a checkout step can't be handled, if it can't.
  func reasonToIgnore(_ checkout: CustomStoreCheckout) -> String? {
    switch (checkout, self) {
    case (.complete, .otherPurchase):
      return nil
    case (_, .otherPurchase):
      return "another purchase is in progress"
    case (.start, .thisCheckout):
      return "it's already in progress"
    case (.abandon, .none),
      (.abandon, .otherCustomStoreCheckout):
      return "no checkout of it is in progress"
    case (.fail, .otherCustomStoreCheckout):
      return "another checkout is in progress"
    default:
      return nil
    }
  }
}
