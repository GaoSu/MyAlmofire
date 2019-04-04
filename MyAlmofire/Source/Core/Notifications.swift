//
//  Notifications.swift
//  MyAlmofire
//
//  Created by Mac on 2019/4/4.
//  Copyright © 2019年 刘航. All rights reserved.
//

import Foundation

extension Notification.Name {
    
    public struct Task {
        
        public static let DidResume = Notification.Name(rawValue: "org.alamofire.notification.name.task.didResume")
        
        public static let DidSuspend = Notification.Name(rawValue: "org.alamofire.notification.name.task.didSuspend")
        
        public static let DidCancel = Notification.Name(rawValue: "org.alamofire.notification.name.task.didCancel")
        
        public static let DidComplete = Notification.Name(rawValue: "org.alamofire.notification.name.task.didComplete")

    }

}

extension Notification {
    public struct Key {
        public static let Task = "org.alamofire.notification.key.task"
        public static let ResponseData = "org.alamofire.notification.key.responseData"
    }
}
