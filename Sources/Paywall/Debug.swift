//
//  File.swift
//  
//
//  Created by brian on 7/28/21.
//

import Foundation
//import Logging

internal func log(_ items: Any...) {
//    if (Paywall.debugLogsEnabled){
        print("Paywall Debug", items)
//    }
}


import Foundation


internal struct Logger
{
    static func shareThatToDebug(string: String, error: Swift.Error? = nil)
    {
        print("[PayWalrus] " + string)
    }
    
    private static func errorString(error: Swift.Error?) -> String
    {
        return error == nil ? "" : " - " + (error?.localizedDescription ?? "")
    }
    
//    private static func docsLinkString(documentation: DocumentationIdentifier?) -> String
//    {
//        return documentation == nil ? "" : " - " +  (buildDocsLink(documentation:documentation) ?? "")
//    }
//
//    private static func buildDocsLink(documentation: DocumentationIdentifier?) -> String?
//    {
//        guard let doc = documentation else {
//            return nil
//        }
//        return "https://app.paywalrus.com/docs?id=\(doc.rawValue)"
//    }
}
