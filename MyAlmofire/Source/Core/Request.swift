//
//  Request.swift
//  MyAlmofire
//
//  Created by 刘 on 2018/10/30.
//  Copyright © 2018年 刘航. All rights reserved.
//

import Foundation

public protocol RequestAdapter{
    func adapt(_ urlRequest: URLRequest) throws -> URLRequest
}

public typealias RequestRetryCompltion = (_ shouldRetry: Bool, _ timeDelay: TimeInterval) -> Void

public protocol RequestRetrier{
    func should(_ manager: SessionManager, retry request: Request, with error: Error,completion: @escaping RequestRetryCompltion)
}

protocol TaskConvertible {
    func task(session: URLSession,adapter: RequestAdapter,queue: DispatchQueue) throws -> URLSessionTask
}

public typealias HTTPHeaders = [String: String]


open class DownloadRequest: Request {
    
}


open class Request{
    
    /// 一个监听上传或者下载进度的闭包
    public typealias ProspressHandler = (Progress) -> Void
    
    enum RequestTask {
        case data(TaskConvertible?,URLSessionTask?)
//        case download(TaskConvertible?,URLSessionTask?)
//        case upload(TaskConvertible?,URLSessionTask?)
//        case stream(TaskConvertible?,URLSessionTask?)
    }
    
    private var taskDelegate: TaskDelegate
    private var taskDelegateLock = NSLock()
    
    /// The delegate for the underlying task.
    open internal(set) var delegate: TaskDelegate {
        get {
            taskDelegateLock.lock() ; defer { taskDelegateLock.unlock() }
            return taskDelegate
        }
        set {
            taskDelegateLock.lock() ; defer { taskDelegateLock.unlock() }
            taskDelegate = newValue
        }
    }

    /// 底层的任务
    open var task: URLSessionTask? { return delegate.task}
    
    public var session: URLSession? = URLSession.shared
    
    open var request: URLRequest? { return task?.originalRequest}
    
    open var response: HTTPURLResponse? {return task?.response as? HTTPURLResponse}
    
    open internal(set) var retryCount: UInt = 0
    
    let originalTask: TaskConvertible?
    
    var startTime: CFAbsoluteTime?
    var endTime: CFAbsoluteTime?
    
    var validations: [() -> Void] = []
    
    init(session: URLSession? = nil,requestTask: RequestTask,error: Error? = nil) {
        self.session = session
        switch requestTask {
        case .data(let originalTask, let task):
            taskDelegate = DataTaskDelegate(task: task)
            self.originalTask = originalTask
//        case .download(let originalTask, let task):
            
//        default:
//            print("other")
        }
        delegate.error = error
        delegate.queue?.addOperation {
            self.endTime = CFAbsoluteTimeGetCurrent()
        }
    }
    
    @discardableResult
    open func authenticate(user: String, password: String, persistence: URLCredential.Persistence = .forSession) -> Self {
        let credential = URLCredential(user: user, password: password, persistence: persistence)
        return authenticate(usingCredential: credential)
    }
    
    @discardableResult
    open func authenticate(usingCredential credential: URLCredential) -> Self {
        delegate.credential = credential
        return self
    }
    
    open class func authorizationHeadler(user: String, password: String) -> (key: String, value: String)? {
        guard let data = "\(user):\(password)".data(using: .utf8) else { return nil }
        let credential = data.base64EncodedString(options: [])
        return (key: "Authorization", value: "Basic\(credential)")
    }
    
    open func resume() {
        guard let task = task else { delegate.queue?.isSuspended = false;  return  }
        if startTime == nil {
            startTime = CFAbsoluteTimeGetCurrent()
        }
        task.resume()
        NotificationCenter.default.post(name: Notification.Name.Task.DidResume, object: self, userInfo: [Notification.Key.Task: task])
    }
    
    open func suspend() {
        guard let task = task else { return }
        task.suspend()
        NotificationCenter.default.post(name: Notification.Name.Task.DidSuspend, object: self, userInfo: [Notification.Key.Task: task])
    }
    
    open func cancel() {
        guard let task = task else { return }
        task.cancel()
        NotificationCenter.default.post(name: Notification.Name.Task.DidCancel, object: self, userInfo: [Notification.Key.Task: task])
    }
}

extension Request: CustomStringConvertible {
    public var description: String {
        var components: [String] = []
        if let HTTPMethod = request?.httpMethod {
            <#statements#>
        }
    }
    
    
}







