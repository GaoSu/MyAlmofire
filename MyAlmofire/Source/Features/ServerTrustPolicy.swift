//
//  ServerTrustPolicy.swift
//  MyAlmofire
//
//  Created by mini on 2019/6/20.
//  Copyright © 2019 刘航. All rights reserved.
//

import Foundation

open class ServerTrustPolicyManager {
    
}

//MARK: -
extension URLSession {
    private struct AssociatedKeys {
        static var managerKey = "URLSession.ServerTrustPolicyManager"
    }
    var serverTrustPolicyManager: ServerTrustPolicyManager? {
        get {
            return objc_getAssociatedObject(self, &AssociatedKeys.managerKey) as? ServerTrustPolicyManager
        }
        set(manager) {
            objc_setAssociatedObject(self, &AssociatedKeys.managerKey, manager, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}
