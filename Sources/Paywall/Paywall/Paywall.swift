import UIKit
import Foundation
import StoreKit
import TPInAppReceipt

@objc public protocol PaywallDelegate: AnyObject {
    
    func userDidInitiateCheckout(for product: SKProduct)
    func shouldTryToRestore()
    
    @objc optional func didReceiveCustomEvent(withName name: String)
    
    @objc optional func willDismissPaywall()
    @objc optional func willPresentPaywall()

    @objc optional func didDismissPaywall()
    @objc optional func didPresentPaywall()
    
    @objc optional func willOpenURL(url: URL)
    @objc optional func willOpenDeepLink(url: URL)

}

public class Paywall: NSObject {
    
    public static var debugMode = false
    
    public static var debugLogsEnabled: Bool = false
    private static var shared: Paywall = Paywall(apiKey: nil)
    
    private var apiKey: String? {
        return Store.shared.apiKey
    }
    private var appUserId: String? {
        return Store.shared.appUserId
    }
    private var aliasId: String? {
        return Store.shared.aliasId
    }
    
    private var willPresent = false

    private(set) var paywallResponse: PaywallResponse?
    
    private(set) var paywallViewController: PaywallViewController?
    
    private(set) var productsById: [String: SKProduct] = [String: SKProduct]()
    
    private var didTryToAutoRestore = false
    
    public static var delegate: PaywallDelegate? = nil
    
    private var paywallId: String {
        paywallResponse?.id ?? ""
    }
    
    // MARK: Initialization
    
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
        
    }
    
    private func setAliasIfNeeded() {
        if Store.shared.aliasId == nil {
            Store.shared.aliasId = "$SuperwallAlias:\(UUID().uuidString)"
            Store.shared.save()
        }
    }

    public static func load(completion: ((Bool) -> ())? = nil) {
        
        Paywall.track(.paywallResponseLoadStart)
        
        Network.shared.paywall { (result) in
            
            switch(result){
            case .success(var response):
                
                Paywall.track(.paywallResponseLoadComplete)
                
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
                            }
                        }
                    }
                    
                    response.variables = variables
                    
                    DispatchQueue.main.async {
                        
                        shared.paywallViewController = PaywallViewController(paywallResponse: response, completion: shared.paywallEventDidOccur)
                        
                        if let v =  UIApplication.shared.keyWindow?.rootViewController {
                            v.addChild(shared.paywallViewController!)
                            shared.paywallViewController!.view.alpha = 0.01
                            v.view.insertSubview(shared.paywallViewController!.view, at: 0)
                            shared.paywallViewController!.view.transform = CGAffineTransform(translationX: 1000, y: 0)
                            shared.paywallViewController!.didMove(toParent: v)
                        }
                        
                        shared.paywallResponse = response
                        completion?(true)

                    }
                    
                }
                
                
                break
            case .failure(let error):
                Logger.superwallDebug(string: "Failed to load paywall", error: error)
                Paywall.track(.paywallResponseLoadFail)
                
                DispatchQueue.main.async {
                    completion?(false)
                }
            }

        }
    }
    
    public static func testLoading() {
        shared.paywallViewController?.loadingState = .loadingPurchase
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false, block: { t in
            shared.paywallViewController?.loadingState = .ready
        })
    }
    
    @discardableResult
    public static func configure(apiKey: String, userId: String? = nil) -> Paywall {
        shared = Paywall(apiKey: apiKey, userId: userId)
        
        
        
        return shared
    }
    
    // MARK: Users
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
    
    @discardableResult
    public static func reset() -> Paywall {
        
        if Store.shared.appUserId != nil {
            Store.shared.clear()
            shared.setAliasIfNeeded()
            shared.paywallViewController = nil
        }
        
        return shared
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
                self?._dismiss()
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
        _dismiss()
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
        _dismiss()
    }
    
    // if a parent needs to approve the purchase
    private func _transactionWasDeferred() {
        paywallViewController?.presentAlert(title: "Waiting for Approval", message: "Thank you! This purchase is pending approval from your parent. Please try again once it is approved.")
        Paywall.track(.transactionFail(paywallId: paywallId, productId: "", message: "Needs parental approval"))
    }
    
    private func _dismiss(_ completion: (()->())? = nil) {
        OnMain { [weak self] in
            Paywall.delegate?.willDismissPaywall?()
            self?.paywallViewController?.dismiss(animated: true, completion: {
                Paywall.delegate?.didDismissPaywall?()
                completion?()
            })
        }
    }
    
    // MARK: Paywall Presentation
    
    public static func present(on viewController: UIViewController? = nil, cached: Bool = true, presentationCompletion: (()->())? = nil, fallback: (() -> ())? = nil) {
        
        guard let delegate = delegate else {
            Logger.superwallDebug(string: "Yikes ... you need to set Paywall.delegate equal to a PaywallDelegate before doing anything fancy")
            fallback?()
            return
        }
        
        
        if shared.willPresent {
            Logger.superwallDebug(string: "A Paywall is already being presented! If you'd like to speed this up, try calling Paywall.preload()")
            return
        }
        
        shared.willPresent = true
        
        let presentationBlock: ((PaywallViewController) -> ()) = { vc in
            if !vc.isBeingPresented {
                shared.paywallViewController?.readyForEventTracking = false
                vc.willMove(toParent: nil)
                vc.view.removeFromSuperview()
                vc.removeFromParent()
                vc.view.alpha = 1.0
                vc.view.transform = .identity
                vc.webview.scrollView.contentOffset = CGPoint.zero
                delegate.willPresentPaywall?()
                
                guard let presentor = (viewController ?? UIApplication.shared.keyWindow?.rootViewController) else {
                    Logger.superwallDebug(string: "No UIViewController to present paywall on. This usually happens when you call this method before a window was made key and visible. Try calling this a little later, or explicitly pass in a UIViewController to present your Paywall on :)")
                    fallback?()
                    return
                }
                
                presentor.present(vc, animated: true, completion: { 
                    self.shared.willPresent = false
                    delegate.didPresentPaywall?()
                    presentationCompletion?()
                    Paywall.track(.paywallOpen(paywallId: self.shared.paywallId))
                    shared.paywallViewController?.readyForEventTracking = true
                })
            }
        }
        
        if let vc = shared.paywallViewController, cached {
            presentationBlock(vc)
            return
        }
        
        load() { success in
            if (success) {
                
                
                guard let vc = shared.paywallViewController else {
                    Logger.superwallDebug(string: "Paywall's viewcontroller is nil!")
                    fallback?()
                    return
                }
                
                guard let _ = shared.paywallResponse else {
                    Logger.superwallDebug(string: "Paywall presented before API response was received")
                    fallback?()
                    return
                }
                
                presentationBlock(vc)
                
            } else {
                self.shared.willPresent = false
                fallback?()
            }
        }
           
        
    }
    
    
    deinit {
        
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
