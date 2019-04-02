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


open class Request{
    
    /// 一个监听上传或者下载进度的闭包
    public typealias ProspressHandler = (Progress) -> Void
    
    enum RequestTask {
        case data(TaskConvertible?,URLSessionTask)
        case download(TaskConvertible?,URLSessionTask)
        case upload(TaskConvertible?,URLSessionTask)
        case stream(TaskConvertible?,URLSessionTask)
    }
    
    private var taskDelegate: TaskDelegate?
    private var taskDelegateLock = NSLock()
    
    open internal(set) var delegate: TaskDelegate {
        get{
            taskDelegateLock.lock() ; defer {taskDelegateLock.unlock()}
            return taskDelegate!
        }
        set{
            taskDelegateLock.lock() ; defer {taskDelegateLock.unlock()}
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
//        switch requestTask {
////        case .data(let originalTask, let task):
////            taskDelegate =
////        default:
////            <#code#>
        }
    }
    
    
    
}
