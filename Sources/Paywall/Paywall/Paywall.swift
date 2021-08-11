import UIKit
import Foundation

@objc public protocol PaywallDelegate: AnyObject {
    
    func userDidInitiateCheckout(forProductWithId productId: String, purchaseCompleted: () -> (), checkoutAbandoned: () -> (), errorOccurred: (NSError) -> ())
    func userDidInitiateRestore(restoreSucceeded: (Bool) -> ())
    
    @objc optional func willDismissPaywall()
    @objc optional func willPresentPaywall()

    @objc optional func didDismissPaywall()
    @objc optional func didPresentPaywall()
    
    @objc optional func willOpenURL(url: URL)
    @objc optional func willOpenDeepLink(url: URL)

}

public class Paywall {
    
    public static var debugLogsEnabled: Bool = false
    public static var shared: Paywall = Paywall(apiKey: nil)
    
    private var apiKey: String? {
        return Store.shared.apiKey
    }
    private var appUserId: String? {
        return Store.shared.appUserId
    }
    private var aliasId: String? {
        return Store.shared.aliasId
    }
    
//    private(set) var paywallLoaded: Bool = false
    private(set) var paywallResponse: PaywallResponse?
    
    private(set) var paywallViewController: PaywallViewController?
    
//    private typealias WhenReadyCompletionBlock = () -> ()
//    private var whenReadyCompletionBlocks: [WhenReadyCompletionBlock] = []
    
//    public typealias PurchaseDidEndCompletionBlock: () -> Bool
    
    public static var delegate: PaywallDelegate? = nil
    
    // MARK: Initialization
    
    private init(apiKey: String?, userId: String? = nil) {
        
        if apiKey == nil {
            return
        }
        
        if let uid = userId {
            self.set(appUserID: uid)
        }

        Store.shared.apiKey = apiKey
        
        setAliasIfNeeded()
        
//        fetchPaywall()

    }
    
    private func setAliasIfNeeded() {
        if Store.shared.aliasId == nil {
            Store.shared.aliasId = "$SuperwallAlias:\(UUID().uuidString)"
            Store.shared.save()
        }
    }

    public static func prereload(completion: @escaping (Bool) -> ()) {
        
        
        Network.shared.paywall { (result) in
            
            switch(result){
            case .success(var response):
                
                
                StoreKitManager.shared.get(productsWithIds: response.productIds) { productsById in
                    
                    
                    var variables = [Variables]()
                    
                    for p in response.products {
                        if let appleProduct = productsById[p.productId] {
                            variables.append(Variables(key: p.product.rawValue, value: appleProduct.eventData))
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
                        
//                        self.whenReadyCompletionBlocks.forEach({$0()})
//                        self.whenReadyCompletionBlocks.removeAll()
                        
                        completion(true)

                    }
                    
                }
                
                
                break
            case .failure(let error):
//                fatalError(error.localizedDescription)
                Logger.superwallDebug(string: "Failed to load paywall", error: error)
                
                DispatchQueue.main.async {
                    completion(false)
                }
            }
//            self.paywallLoaded = true
        }
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
    
//    // helper func, closure only called after .success in init
//    private func whenReady(_ block: @escaping WhenReadyCompletionBlock) {
//        if paywallLoaded {
//            block()
//        } else {
//            whenReadyCompletionBlocks.append(block)
//        }
//    }
    
    // we can make this overridable one day?
    private func paywallEventDidOccur(result: PaywallPresentationResult) {
        
        switch result {
        case .closed:
            _dismiss()
        case .initiatePurchase(let productId):
//            Paywall.delegate?.userDidInitiateCheckout(forProductWithId: productId, purchaseSucceeded: { success in
//                if success {
//                    _purchaseDidSucceed(forProductWithId: productId)
//                } else {
//                    _purchaseWasAbandoned(forProductWithId: productId)
//                }
//            })
            
            
            Paywall.delegate?.userDidInitiateCheckout(forProductWithId: productId, purchaseCompleted: {
                _purchaseDidSucceed(forProductWithId: productId)
            }, checkoutAbandoned: {
                _checkoutWasAbandoned(forProductWithId: productId)
            }, errorOccurred: { error in
                _purchaseErrorDidOccur(error: error, forProductWithId: productId)
            })
        case .initiateResotre:
            Paywall.delegate?.userDidInitiateRestore(restoreSucceeded: { success in
                if success {
                    _restoreDidSucceed()
                } else {
                    _restoreDidFail()
                }
            })
        case .openedURL(let url):
            Paywall.delegate?.willOpenURL?(url: url)
        case .openedDeepLink(let url):
            Paywall.delegate?.willOpenDeepLink?(url: url)
        }
    }
    
    // purchase callbacks
    private func _purchaseDidSucceed(forProductWithId productId: String) {
        // TODO: ANALYTICS
        _dismiss()
    }
    
    private func _purchaseErrorDidOccur(error: NSError, forProductWithId productId: String) {
        // TODO: ANALYTICS
        
    }
    
    private func _checkoutWasAbandoned(forProductWithId productId: String) {
        // TODO: ANALYTICS
        
    }

    // restore callbacks
    private func _restoreDidSucceed() {
        // TODO: ANALYTICS
        _dismiss()
    }

    private func _restoreDidFail() {
        // TODO: ANALYTICS
        
    }

    
    private func _dismiss() {
        Paywall.delegate?.willDismissPaywall?()
        paywallViewController?.dismiss(animated: true, completion: {
            Paywall.delegate?.didDismissPaywall?()
        })
    }
    
    private static func _present( on presentOn: UIViewController? = nil, presentationCompletion: (()->())? = nil) {


        
    }
    
    // MARK: Paywall Presentation
    
    public static func present(on viewController: UIViewController? = nil, cached: Bool = false, presentationCompletion: (()->())? = nil, fallback: (() -> ())? = nil) {
        
        guard let delegate = delegate else {
            Logger.superwallDebug(string: "Yikes ... you need to set Paywall.delegate equal to a PaywallDelegate before doing anything fancy")
            fallback?()
            return
        }
        
        guard let presentor = (viewController ?? UIApplication.shared.keyWindow?.rootViewController) else {
            Logger.superwallDebug(string: "No UIViewController to present paywall on. This usually happens when you call this method before a window was made key and visible. Try calling this a little later, or explicitly pass in a UIViewController to present your Paywall on :)")
            fallback?()
            return
        }
        
        let presentationBlock: ((PaywallViewController) -> ()) = { vc in
            if !vc.isBeingPresented {
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
                })
            }
        }
        
        if let vc = shared.paywallViewController, cached {
            presentationBlock(vc)
            return
        }
        
        prereload() { success in
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
                fallback?()
            }
        }
           
        
    }
}
