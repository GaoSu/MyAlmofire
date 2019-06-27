//
//  DispatchQueue+Alamofire.swift
//  MyAlmofire
//
//  Created by mini on 2019/6/24.
//  Copyright © 2019 刘航. All rights reserved.
//

import Foundation
import Dispatch

extension DispatchQueue {
    static var userInteractive: DispatchQueue {
        return DispatchQueue.global(qos: .userInteractive)
    }
    
    static var userInitiated: DispatchQueue {
        return DispatchQueue.global(qos: .userInitiated)
    }
    
    static var utility: DispatchQueue {
        return DispatchQueue.global(qos: .utility)
    }
    
    static var background: DispatchQueue {
        return DispatchQueue.global(qos: .background)
    }
    
    func after(_ delay: TimeInterval, execute closure: @escaping() -> Void) {
       asyncAfter(deadline: .now() + delay, execute: closure)
    }
}
