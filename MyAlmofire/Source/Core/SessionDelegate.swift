//
//  SessionDelegate.swift
//  MyAlmofire
//
//  Created by mini on 2019/6/20.
//  Copyright © 2019 刘航. All rights reserved.
//

import Foundation

open class SessionDelegate: NSObject {
    //MARK: -properties
    var retrier: RequestRetrier?
    weak var sessionManager: SessionManager?
    
    open var sessionDidFinishEventsForBackgroundURLSession: ((URLSession) -> Void)?
    private let lock = NSLock()
    var requests: [Int: Request] = [:]
    
    open subscript(task: URLSessionTask) -> Request? {
        get { lock.lock() ; defer { lock.unlock() }
            return requests[task.taskIdentifier]
        }
        set {
            lock.lock() ; defer { lock.unlock() }
            requests[task.taskIdentifier] = newValue
        }
    }
}

extension SessionDelegate: URLSessionDelegate {
    
}
