//
//  File.swift
//  
//
//  Created by Jake Mor on 8/4/21.
//

//import UIKit
//import Paywall
//
//class ViewController: UIViewController {
//
//    override func viewDidLoad() {
//        super.viewDidLoad()
//        view.backgroundColor = .darkGray
//
//        Paywall.debugLogsEnabled = true
//        Paywall.config(withAPIKey: "1234", appUserID: "12345")
//        Paywall.delegate = self
//
//        Paywall.present()
//    }
//
//
//    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
//        Paywall.present()
//    }
//
//}
//
//
//extension ViewController: PaywallDelegate {
//
//    func userDidInitiateCheckout(forProductWithId id: String,
//                                 purchaseCompleted: () -> (),
//                                 checkoutAbandoned: () -> (),
//                                 errorOccurred: (NSError) -> ()) {
//
//    }
//
//    func userDidInitiateRestore(restoreSucceeded: (Bool) -> ()) {
//
//    }
//
//
//}

