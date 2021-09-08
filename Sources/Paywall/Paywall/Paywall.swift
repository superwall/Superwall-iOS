import UIKit
import Foundation
import StoreKit
import TPInAppReceipt

/// Methods for managing important Paywall lifecycle events. For example, telling the developer when to initiate checkout on a specific `SKProduct` and when to try to restore a transaction. Also includes hooks for you to log important analytics events to your product analytics tool.
@objc public protocol PaywallDelegate: AnyObject {
    
    /// Called when the user initiates checkout for a product. Add your purchase logic here by either calling `Purchases.shared.purchaseProduct()` (if you use RevenueCat: https://sdk.revenuecat.com/ios/Classes/RCPurchases.html#/c:objc(cs)RCPurchases(im)purchaseProduct:withCompletionBlock:) or by using Apple's StoreKit APIs
    /// - Parameter product: The `SKProduct` the user would like to purchase
    func userDidInitiateCheckout(for product: SKProduct)
    
    /// Called when the user initiates a restore. Add your restore logic here.
    func shouldTryToRestore()
    
    /// Called before ever showing a paywall. Return `false` if the user has active entitlements and `true` if the user does not.
    @objc func shouldPresentPaywall() -> Bool
    
    /// Called when the user taps a button with a custom `data-pw-custom` tag in your HTML paywall. See paywall.js for further documentation
    ///  - Parameter withName: The value of the `data-pw-custom` tag in your HTML element that the user selected.
    @objc optional func didReceiveCustomEvent(withName name: String)
    
    /// Called right before the paywall is dismissed.
    @objc optional func willDismissPaywall()
    
    /// Called right before the paywall is presented.
    @objc optional func willPresentPaywall()

    /// Called right after the paywall is dismissed.
    @objc optional func didDismissPaywall()
    
    /// Called right after the paywall is presented.
    @objc optional func didPresentPaywall()
    
    /// Called when the user opens a URL by selecting an element with the `data-pw-open-url` tag in your HTML paywall.
    @objc optional func willOpenURL(url: URL)
    
    /// Called when the user taps a deep link in your HTML paywall.
    @objc optional func willOpenDeepLink(url: URL)
    
    /// Called when you should track a standard internal analytics event to your own system. If you want the event's name as an enum, do this:`let e = Paywall.EventName(rawValue: name)`
    ///
    
    /// Possible Values:
    ///  ```swift
    /// // App Lifecycle Events
    /// Paywall.delegate.shouldTrack(event: "app_install", params: nil)
    /// Paywall.delegate.shouldTrack(event: "app_open", params: nil)
    /// Paywall.delegate.shouldTrack(event: "app_close", params: nil)
    ///
    /// // Paywall Events
    /// Paywall.delegate.shouldTrack(event: "paywall_open", params: ['paywall_id': 'someid'])
    /// Paywall.delegate.shouldTrack(event: "paywall_close", params: ['paywall_id': 'someid'])
    ///
    /// // Transaction Events
    /// Paywall.delegate.shouldTrack(event: "transaction_start", params: ['paywall_id': 'someid', 'product_id': 'someskid'])
    /// Paywall.delegate.shouldTrack(event: "transaction_fail", params: ['paywall_id': 'someid', 'product_id': 'someskid'])
    /// Paywall.delegate.shouldTrack(event: "transaction_abandon", params: ['paywall_id': 'someid', 'product_id': 'someskid'])
    /// Paywall.delegate.shouldTrack(event: "transaction_complete", params: ['paywall_id': 'someid', 'product_id': 'someskid'])
    /// Paywall.delegate.shouldTrack(event: "transaction_restore", params: ['paywall_id': 'someid', 'product_id': 'someskid'])
    ///
    /// // Purchase Events
    /// Paywall.delegate.shouldTrack(event: "subscription_start", params: ['paywall_id': 'someid', 'product_id': 'someskid'])
    /// Paywall.delegate.shouldTrack(event: "freeTrial_start", params: ['paywall_id': 'someid', 'product_id': 'someskid'])
    /// Paywall.delegate.shouldTrack(event: "nonRecurringProduct_purchase", params: ['paywall_id': 'someid', 'product_id': 'someskid'])
    ///
    /// // Superwall API Request Events
    /// Paywall.delegate.shouldTrack(event: "paywallResponseLoad_start", params: ['paywall_id': 'someid'])
    /// Paywall.delegate.shouldTrack(event: "paywallResponseLoad_fail", params: ['paywall_id': 'someid'])
    /// Paywall.delegate.shouldTrack(event: "paywallResponseLoad_complete", params: ['paywall_id': 'someid'])
    ///
    /// // Webview Reqeuest Events
    /// Paywall.delegate.shouldTrack(event: "paywallWebviewLoad_start", params: ['paywall_id': 'someid'])
    /// Paywall.delegate.shouldTrack(event: "paywallWebviewLoad_fail", params: ['paywall_id': 'someid'])
    /// Paywall.delegate.shouldTrack(event: "paywallWebviewLoad_complete", params: ['paywall_id': 'someid'])
    /// ```
    
    
    @objc optional func shouldTrack(event: String, params: [String: Any])

}

/// `Paywall` is the primary class for integrating Superwall into your application. To learn more, read our iOS getting started guide: https://docs.superwall.me/docs/ios
public class Paywall: NSObject {
    
    // MARK: Public
    
    /// Prints debug logs to the console if set to `true`. Default is `false`
    public static var debugMode = false
    
    /// WARNING: Only use this enum to set `Paywall.networkEnvironment` if told so explicitly by the Superwall team.
    public enum PaywallNetworkEnvironment {
        /// Default: Use the standard latest environment
        case release
        /// Use a release candidate environment
        case releaseCandidate
        /// Use the nightly build environment
        case developer
    }
    
    /// WARNING: Determines which network environment your SDK should use. Defaults to latest. You should under no circumstance change this unless you received the go-ahead from the Superwall team.
    public static var networkEnvironment: PaywallNetworkEnvironment = .release
    
    /// The object that acts as the delegate of Paywall. Required implementations include `userDidInitiateCheckout(for product: SKProduct)` and `shouldTryToRestore()`. 
    public static var delegate: PaywallDelegate? = nil
    
    /// Completion block of type `(Bool) -> ()` that is optionally passed through `Paywall.present()`. Gets called when the paywall is dismissed by the user, by way or purchasing, restoring or manually dismissing. Accepts a BOOL that is `true` if the product is purchased or restored, and `false` if the user manually dismisses the paywall.
    /// Please note: This completion is NOT called when  `Paywall.dismiss()` is manually called by the developer.
    public typealias PurchaseCompletionBlock = (Bool) -> ()
    
    /// Completion block that is optionally passed through `Paywall.present()`. Gets called if an error occurs while presenting a Superwall paywall, or if all paywalls are set to off in your dashboard. It's a good idea to add your legacy paywall presentation logic here just in case :)
    public typealias FallbackBlock = () -> ()
    
    /// Launches the debugger for you to preview paywalls. If you call `Paywall.track(.deepLinkOpen(deepLinkUrl: url))` from `application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool` in your `AppDelegate`, this funciton is called automatically after scanning your debug QR code in Superwall's web dashboard. Remember to add you URL scheme in settings for this feature to work!
    public static func launchDebugger(toPaywall paywallId: String? = nil) {
        isDebuggerLaunched = true
        Paywall.dismiss(nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.618) { // helps if from cold launch
            
            if let vc = UIViewController.topMostViewController {
                
                var dvc: SWDebugViewController? = nil
                var isPresented = false
                
                if vc is SWDebugViewController {
                    dvc = vc as? SWDebugViewController
                    isPresented = true
                } else {
                    dvc = SWDebugViewController()
                }
                
                dvc?.paywallId = paywallId
                
                if let dvc = dvc {
                    
                    if isPresented {
                        dvc.loadPreview()
                    } else {
                        dvc.modalPresentationStyle = .overFullScreen
                        vc.present(dvc, animated: true)
                    }
                }
                
                
            }
        }
    }
    
    internal static func set(response r: PaywallResponse?, completion: ((Bool) -> ())? = nil) {
        
        guard let r = r else {
            self.shared.paywallViewController = nil
            return
        }
        
        shared.paywallResponse = r
        var response = shared.paywallResponse!
        StoreKitManager.shared.get(productsWithIds: response.productIds) { productsById in
            
            var variables = [Variables]()
            
            for p in response.products {
                if let appleProduct = productsById[p.productId] {
                    variables.append(Variables(key: p.product.rawValue, value: appleProduct.eventData))
                    shared.productsById[p.productId] = appleProduct
                    
                    if p.product == .primary {
                        
                        response.isFreeTrialAvailable = appleProduct.hasFreeTrial
                        
                        if let receipt = try? InAppReceipt.localReceipt() {
                            let hasPurchased = receipt.containsPurchase(ofProductIdentifier: p.productId)
                            if hasPurchased && appleProduct.hasFreeTrial {
                                response.isFreeTrialAvailable = false
                            }
                        }
                        
                        // use the override if it is set
                        if let or = isFreeTrialAvailableOverride {
                            response.isFreeTrialAvailable = or
                            isFreeTrialAvailableOverride = nil // reset it for future use
                        }
                    }
                }
            }
            
            response.variables = variables
            
            DispatchQueue.main.async {
                
                shared.paywallViewController = SWPaywallViewController(paywallResponse: response, completion: shared.paywallEventDidOccur)
                
                if let v =  UIApplication.shared.keyWindow?.rootViewController {
                    v.addChild(shared.paywallViewController!)
                    shared.paywallViewController!.view.alpha = 0.01
                    v.view.insertSubview(shared.paywallViewController!.view, at: 0)
                    shared.paywallViewController!.view.transform = CGAffineTransform(translationX: 1000, y: 0)
                    shared.paywallViewController!.didMove(toParent: v)
                }
                
                completion?(true)

            }
            
        }
    }
    
    internal static var isLoadingPaywallResponse = false
    
    /// Pre-loads your paywall so it loads instantly on `Paywall.present()`.
    /// - Parameter completion: A completion block of type `((Bool) -> ())?`, defaulting to nil if not provided. `true` on success, and `false` on failure.
    public static func load(completion: ((Bool) -> ())? = nil) {
        
        if isLoadingPaywallResponse {
            return
        }
        
        Paywall.track(.paywallResponseLoadStart)
        
        isLoadingPaywallResponse = true
        
        Network.shared.paywall { (result) in
            
            switch(result){
            case .success(let response):
                
                Paywall.track(.paywallResponseLoadComplete)
                Paywall.set(response: response, completion: completion)
                
                
                break
            case .failure(let error):
                Logger.superwallDebug(string: "Failed to load paywall", error: error)
                Paywall.track(.paywallResponseLoadFail)
                
                DispatchQueue.main.async {
                    completion?(false)
                }
            }
            
            isLoadingPaywallResponse = false

        }
    }
    
    /// Configures an instance of Superwall's Paywall SDK with a specified API key. If you don't pass through a userId, we'll create one for you. Calling `Paywall.identify(userId: String)` in the future will automatically alias these two for simple reporting.
    ///  - Parameter apiKey: Your Public API Key from: https://superwall.me/applications/1/settings/keys
    ///  - Parameter userId: Your user's unique identifier, as defined by your backend system.
    @discardableResult
    public static func configure(apiKey: String, userId: String? = nil) -> Paywall {
        shared = Paywall(apiKey: apiKey, userId: userId)
        return shared
    }
    
    /// Links your userId to Superwall's automatically generated Alias. Call this as soon as you have a userId.
    ///  - Parameter userId: Your user's unique identifier, as defined by your backend system.
    @discardableResult
    public static func identify(userId: String) -> Paywall {
        
        if Store.shared.userId != userId { // refetch the paywall, we don't know if the alias was for an existing user
            shared.set(appUserID: userId)
            shared.paywallViewController = nil
        } else {
            shared.set(appUserID: userId)
        }
        
        return shared
    }
    
    /// Resets the userId stored by Superwall. Call this when your user signs out.
    @discardableResult
    public static func reset() -> Paywall {
        
        if Store.shared.appUserId != nil {
            Store.shared.clear()
            shared.setAliasIfNeeded()
            shared.paywallViewController = nil
        }
        
        return shared
    }
    
    /// Dismisses the presented paywall. Doesn't trigger a `PurchaseCompletionBlock` call if provided during `Paywall.present()`, since this action is developer initiated.
    /// - Parameter completion: A completion block of type `(()->())? = nil` that gets called after the paywall is dismissed.
    public static func dismiss(_ completion: (()->())? = nil) {
        shared._dismiss(completion: completion)
    }
    
    // for convenience
    
    /// Presents a paywall to the user.
    ///  - Parameter cached: Determines if Superwall shoudl re-fetch a paywall from the user. You should typically set this to `false` only if you think your user may now conditionally match a rule for another paywall. Defaults to `true`.
    ///  - Parameter presentationCompletion: A completion block that gets called immediately after the paywall is presented. Defaults to  `nil`,
    ///  - Parameter purchaseCompletion: Gets called when the paywall is dismissed by the user, by way of purchasing, restoring or manually dismissing. Accepts a `Bool` that is `true` if the product is purchased or restored, and `false` if the paywall is manually dismissed by the user.
    public static func present(cached: Bool, presentationCompletion:  (()->())? = nil, purchaseCompletion: PurchaseCompletionBlock? = nil) {
        present(on: nil, cached: cached, presentationCompletion: presentationCompletion, purchaseCompletion: purchaseCompletion, fallback: nil)
    }
    
    /// Presents a paywall to the user.
    ///  - Parameter presentationCompletion: A completion block that gets called immediately after the paywall is presented. Defaults to  `nil`,
    ///  - Parameter purchaseCompletion: Gets called when the paywall is dismissed by the user, by way of purchasing, restoring or manually dismissing. Accepts a `Bool` that is `true` if the product is purchased or restored, and `false` if the paywall is manually dismissed by the user.
    public static func present(presentationCompletion: (()->())? = nil, purchaseCompletion: PurchaseCompletionBlock? = nil) {
        present(on: nil, presentationCompletion: presentationCompletion, purchaseCompletion: purchaseCompletion, fallback: nil)
    }
    
    /// Presents a paywall to the user.
    ///  - Parameter purchaseCompletion: Gets called when the paywall is dismissed by the user, by way of purchasing, restoring or manually dismissing. Accepts a `Bool` that is `true` if the product is purchased or restored, and `false` if the paywall is manually dismissed by the user.
    public static func present(purchaseCompletion: PurchaseCompletionBlock? = nil) {
        present(on: nil, presentationCompletion: nil, purchaseCompletion: purchaseCompletion, fallback: nil)
    }
    
    /// Presents a paywall to the user.
    ///  - Parameter cached: Determines if Superwall shoudl re-fetch a paywall from the user. You should typically set this to `false` only if you think your user may now conditionally match a rule for another paywall. Defaults to `true`.
    public static func present(cached: Bool) {
        present(on: nil, cached: cached, presentationCompletion: nil, purchaseCompletion: nil, fallback: nil)
    }
    
    /// Presents a paywall to the user.
    public static func present() {
        present(on: nil, presentationCompletion: nil, purchaseCompletion: nil, fallback: nil)
    }
    
    /// Presents a paywall to the user.
    ///  - Parameter on: The view controller to present the paywall on. Presents on the `keyWindow`'s `rootViewController` if `nil`. Defaults to `nil`.
    ///  - Parameter cached: Determines if Superwall shoudl re-fetch a paywall from the user. You should typically set this to `false` only if you think your user may now conditionally match a rule for another paywall. Defaults to `true`.
    ///  - Parameter presentationCompletion: A completion block that gets called immediately after the paywall is presented. Defaults to  `nil`,
    ///  - Parameter purchaseCompletion: Gets called when the paywall is dismissed by the user, by way of purchasing, restoring or manually dismissing. Accepts a `Bool` that is `true` if the product is purchased or restored, and `false` if the paywall is manually dismissed by the user.
    public static func present(on viewController: UIViewController? = nil, cached: Bool = true, presentationCompletion: (()->())? = nil, purchaseCompletion: PurchaseCompletionBlock? = nil, fallback: FallbackBlock? = nil) {
        
        guard (delegate?.shouldPresentPaywall() ?? false) else { return }
        
        if isDebuggerLaunched {
            guard viewController is SWDebugViewController else { return }
        }
        
        self.purchaseCompletion = purchaseCompletion
        
        let fallbackUsing = fallback ?? fallbackCompletionBlock
        
        guard let delegate = delegate else {
            Logger.superwallDebug(string: "Yikes ... you need to set Paywall.delegate equal to a PaywallDelegate before doing anything fancy")
            fallbackUsing?()
            return
        }
        
//        if shared.willPresent {
//            Logger.superwallDebug(string: "A Paywall is already being presented! If you'd like to speed this up, try calling Paywall.load()")
//            return
//        }
//
//        shared.willPresent = true
        
        let presentationBlock: ((SWPaywallViewController) -> ()) = { vc in
            
//            if !vc.isBeingPresented {
                guard let presentor = (viewController ?? UIViewController.topMostViewController) else {
                    Logger.superwallDebug(string: "No UIViewController to present paywall on. This usually happens when you call this method before a window was made key and visible. Try calling this a little later, or explicitly pass in a UIViewController to present your Paywall on :)")
                    fallbackUsing?()
                    return
                }
                
                let isPresented = (presentor as? SWPaywallViewController) != nil
                
                if !isPresented {
                    shared.paywallViewController?.readyForEventTracking = false
                    vc.willMove(toParent: nil)
                    vc.view.removeFromSuperview()
                    vc.removeFromParent()
                    vc.view.alpha = 1.0
                    vc.view.transform = .identity
                    vc.webview.scrollView.contentOffset = CGPoint.zero
                    delegate.willPresentPaywall?()
                    
                    presentor.present(vc, animated: true, completion: {
                        delegate.didPresentPaywall?()
                        presentationCompletion?()
                        Paywall.track(.paywallOpen(paywallId: self.shared.paywallId))
                        shared.paywallViewController?.readyForEventTracking = true
                    })
                } else {
                    Logger.superwallDebug(string: "Note: A Paywall is already being presented")
                }
//            }
        }
        
        if let vc = shared.paywallViewController, cached {
            presentationBlock(vc)
            return
        }
        
        load() { success in
            
            if (success) {
                
                guard let vc = shared.paywallViewController else {
                    Logger.superwallDebug(string: "Paywall's viewcontroller is nil!")
                    fallbackUsing?()
                    return
                }
                
                guard let _ = shared.paywallResponse else {
                    Logger.superwallDebug(string: "Paywall presented before API response was received")
                    fallbackUsing?()
                    return
                }
                
                presentationBlock(vc)
                
            } else {
                fallbackUsing?()
            }
        }
           
        
    }
    
    
    // MARK: Private
    
    internal static var purchaseCompletion: PurchaseCompletionBlock? = nil
    internal static var fallbackCompletionBlock: FallbackBlock? = nil
    
    private static var shared: Paywall = Paywall(apiKey: nil)
    
    internal static var isFreeTrialAvailableOverride: Bool? = nil
    
    private var apiKey: String? {
        return Store.shared.apiKey
    }
    private var appUserId: String? {
        return Store.shared.appUserId
    }
    private var aliasId: String? {
        return Store.shared.aliasId
    }
    
    internal static var isDebuggerLaunched = false

    private(set) var paywallResponse: PaywallResponse?
    
    private(set) var paywallViewController: SWPaywallViewController?
    
    private(set) var productsById: [String: SKProduct] = [String: SKProduct]()
    
    private var didTryToAutoRestore = false
    
    private var paywallId: String {
        paywallResponse?.id ?? ""
    }
    
    
    private init(apiKey: String?, userId: String? = nil) {
        
        super.init()
        
        if apiKey == nil {
            return
        }
        
        if let uid = userId {
            self.set(appUserID: uid)
        }

        Store.shared.apiKey = apiKey
        
        setAliasIfNeeded()
        
        SKPaymentQueue.default().add(self)
        
        NotificationCenter.default.addObserver(self, selector: #selector(applicationWillResignActive(_:)), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidBecomeActive(_:)), name: UIApplication.didBecomeActiveNotification, object: nil)
        
    }
    
    private func setAliasIfNeeded() {
        if Store.shared.aliasId == nil {
            Store.shared.aliasId = "$SuperwallAlias:\(UUID().uuidString)"
            Store.shared.save()
        }
    }

    
    @discardableResult
    private func set(appUserID: String) -> Paywall {
        Store.shared.appUserId = appUserID
        Store.shared.save()
        return self
    }
    

    private func paywallEventDidOccur(result: PaywallPresentationResult) {
        OnMain { [weak self] in
            switch result {
            case .closed:
                self?._dismiss(userDidPurchase: false)
            case .initiatePurchase(let productId):
                // TODO: make sure this can NEVER happen
                guard let product = self?.productsById[productId] else { return }
                self?.paywallViewController?.loadingState = .loadingPurchase
                Paywall.delegate?.userDidInitiateCheckout(for: product)
            case .initiateRestore:
                Paywall.delegate?.shouldTryToRestore()
            case .openedURL(let url):
                Paywall.delegate?.willOpenURL?(url: url)
            case .openedDeepLink(let url):
                Paywall.delegate?.willOpenDeepLink?(url: url)
            case .custom(let string):
                Paywall.delegate?.didReceiveCustomEvent?(withName: string)
            }
        }
    }
    
    // purchase callbacks
    
    private func _transactionDidBegin(for product: SKProduct) {
        Paywall.track(.transactionStart(paywallId: paywallId, productId: product.productIdentifier))
        paywallViewController?.loadingState = .loadingPurchase
    }

    
    private func _transactionDidSucceed(for product: SKProduct) {
        Paywall.track(.transactionComplete(paywallId: paywallId, productId: product.productIdentifier))
        
        if let ft = paywallResponse?.isFreeTrialAvailable {
            if ft {
                Paywall.track(.freeTrialStart(paywallId: paywallId, productId: product.productIdentifier))
            } else {
                Paywall.track(.subscriptionStart(paywallId: paywallId, productId: product.productIdentifier))
            }
        }
        
        _dismiss(userDidPurchase: true)
    }
    
    
    private func _transactionErrorDidOccur(error: SKError?, for product: SKProduct) {
        // prevent a recursive loop
        OnMain { [weak self] in
            
            guard let self = self else { return }
            
            if !self.didTryToAutoRestore {
                Paywall.delegate?.shouldTryToRestore()
                self.didTryToAutoRestore = true
            } else {
                Paywall.track(.transactionFail(paywallId: self.paywallId, productId: product.productIdentifier, message: error?.localizedDescription ?? ""))
                self.paywallViewController?.presentAlert(title: "Please try again", message: error?.localizedDescription ?? "", actionTitle: "Restore Purchase", action: {
                    Paywall.delegate?.shouldTryToRestore()
                })
            }
        }
    }
    
    private func _transactionWasAbandoned(for product: SKProduct) {
        Paywall.track(.transactionAbandon(paywallId: paywallId, productId: product.productIdentifier))
        paywallViewController?.loadingState = .ready
    }
    
    private func _transactionWasRestored() {
        Paywall.track(.transactionRestore(paywallId: paywallId, productId: ""))
        _dismiss(userDidPurchase: true)
    }
    
    // if a parent needs to approve the purchase
    private func _transactionWasDeferred() {
        paywallViewController?.presentAlert(title: "Waiting for Approval", message: "Thank you! This purchase is pending approval from your parent. Please try again once it is approved.")
        Paywall.track(.transactionFail(paywallId: paywallId, productId: "", message: "Needs parental approval"))
    }
    

    
    private func _dismiss(userDidPurchase: Bool? = nil, completion: (()->())? = nil) {
        OnMain { [weak self] in
            Paywall.delegate?.willDismissPaywall?()
            self?.paywallViewController?.dismiss(animated: true, completion: { [weak self] in
                Paywall.delegate?.didDismissPaywall?()
                self?.paywallViewController?.loadingState = .ready
                completion?()
                if let s = userDidPurchase {
                    Paywall.purchaseCompletion?(s)
                }
                
            })
        }
    }
    
    
    @objc func applicationWillResignActive(_ sender: AnyObject? = nil) {
        Paywall.track(.appClose)
    }
    
    @objc func applicationDidBecomeActive(_ sender: AnyObject? = nil) {
        Paywall.track(.appOpen)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.didBecomeActiveNotification, object: nil)
    }
    
}



extension Paywall: SKPaymentTransactionObserver {
 
    public func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        for transaction in transactions {
            guard let product = productsById[transaction.payment.productIdentifier] else { return }
            switch transaction.transactionState {
            case .purchased:
                queue.finishTransaction(transaction)
                Logger.superwallDebug(string: "[Transaction Observer] transactionDidSucceed for: \(product.productIdentifier)")
                self._transactionDidSucceed(for: product)
            break
            case .failed:
                // TODO: Check if purcahse was canceled,
                if let e = transaction.error as? SKError {
                    var userCancelled = e.code == .paymentCancelled
                    if #available(iOS 12.2, *) {
                        userCancelled = e.code == .overlayCancelled || e.code == .paymentCancelled
                    }

                    if #available(iOS 14.0, *) {
                        userCancelled = e.code == .overlayCancelled || e.code == .paymentCancelled || e.code == .overlayTimeout
                    }

                    if userCancelled {
                        Logger.superwallDebug(string: "[Transaction Observer] transactionWasAbandoned for: \(product.productIdentifier)")
                        self._transactionWasAbandoned(for: product)
                        return
                    } else {
                        Logger.superwallDebug(string: "[Transaction Observer] transactionErrorDidOccur for: \(product.productIdentifier)")
                        self._transactionErrorDidOccur(error: e, for: product)
                        return
                    }
                }
              
            break
            case .restored:
                Logger.superwallDebug(string: "[Transaction Observer] transactionWasRestored")
                _transactionWasRestored()
            break
            case .deferred:
                Logger.superwallDebug(string: "[Transaction Observer] deferred")
                _transactionWasDeferred()
            case .purchasing:
                Logger.superwallDebug(string: "[Transaction Observer] purchasing")
                _transactionDidBegin(for: product)
            default:
                paywallViewController?.loadingState = .ready
            }
        }
    }
}


internal func OnMain(_ execute: @escaping () -> Void) {
    DispatchQueue.main.async(execute: execute)
}


internal extension UIViewController {
    static var topMostViewController: UIViewController? {
        var presentor: UIViewController? = UIApplication.shared.keyWindow?.rootViewController
        
        while let p = presentor?.presentedViewController {
            presentor = p
        }
        
        return presentor
    }
}

