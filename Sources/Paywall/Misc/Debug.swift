//
//  File.swift
//  
//
//  Created by brian on 7/28/21.
//

import Foundation


internal struct Logger {
    
    static func superwallDebug(_ items: Any...) {
//        print("[Superwall]", items)
    }
    
    static func superwallDebug(string: String, error: Swift.Error? = nil) {
//        print("[Superwall] " + string)
        if let e = error {
//            print("[Superwall]  →", e)
        }
    }
    
    private static func errorString(error: Swift.Error?) -> String {
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
