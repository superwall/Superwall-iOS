//
//  File.swift
//  
//
//  Created by brian on 8/16/21.
//

import Foundation
import UIKit

let serialQueue = DispatchQueue(label: "me.superwall.eventQueue")
let MaxEventCount = 50;

internal class EventsQueue {
    
    private var elements: [JSON] = [];
    private var timer: Timer?
    
    public init () {
        
		timer = Timer.scheduledTimer(timeInterval: Paywall.networkEnvironment == .release ? 20.0 : 1.0 , target:self, selector: #selector(flush), userInfo: nil, repeats: true)
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(flush), name: UIApplication.willResignActiveNotification, object: nil)
    }
    
    func addEvent(event: JSON) {
        serialQueue.async {
            self.elements.append(event);
        }
    }
    
    @objc
    func flush() {
        serialQueue.async {
            self.flushInternal()
        }
    }
    
    private func flushInternal(depth: Int = 10) {
        var eventsToSend: [JSON] = [];
        
        var i = 0;
        while(i < MaxEventCount && elements.count > 0) {
            eventsToSend.append(elements.removeFirst())
            i += 1;
        }
        
        if (eventsToSend.count > 0) {
            // Send to network
            // Network.events(Network)
            Network.shared.events(events: EventsRequest(events: eventsToSend)){
                (result) in
//                Logger.superwallDebug("Events Queue:", result)
            }
        }
		
        if (elements.count > 0 && depth > 0) {
            return flushInternal(depth: depth - 1)
        }
    }

    deinit {
        timer?.invalidate()
        timer = nil
        NotificationCenter.default.removeObserver(self)
    }
}
