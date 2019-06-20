//
//  Request.swift
//  MyAlmofire
//
//  Created by 刘 on 2018/10/30.
//  Copyright © 2018年 刘航. All rights reserved.
//

import Foundation


public typealias RequestRetryCompltion = (_ shouldRetry: Bool, _ timeDelay: TimeInterval) -> Void

public protocol RequestRetrier{
    func should(_ manager: SessionManager, retry request: Request, with error: Error,completion: @escaping RequestRetryCompltion)
}

protocol TaskConvertible {
    func task(session: URLSession, adapter: RequestAdapter?, queue: DispatchQueue) throws -> URLSessionTask
}

public typealias HTTPHeaders = [String: String]


open class Request{
    
    /// 一个监听上传或者下载进度的闭包
    public typealias ProspressHandler = (Progress) -> Void
    
    enum RequestTask {
        case data(TaskConvertible?,URLSessionTask?)
        case download(TaskConvertible?,URLSessionTask?)
        case upload(TaskConvertible?,URLSessionTask?)
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
  
    init(session: URLSession? = nil, requestTask: RequestTask,error: Error? = nil) {
        self.session = session
        switch requestTask {
        case .data(let originalTask, let task):
            taskDelegate = DataTaskDelegate(task: task)
            self.originalTask = originalTask
        case .download(let originalTask, let task):
            taskDelegate = DownloadTaskDelegate(task: task)
            self.originalTask = originalTask
        case .upload(let originalTask, let task):
            taskDelegate = UploadTaskDelegate(task: task)
            self.originalTask = originalTask
//        case .stream(let originalTask, let task):
//            taskDelegate = taskDelegate
        default:
            print("other")
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

// MARK: - CustomStringConvertible

extension Request: CustomStringConvertible {
    public var description: String {
        var components: [String] = []
        if let HTTPMethod = request?.httpMethod {
            components.append(HTTPMethod)
        }
        if let urlString = request?.url?.absoluteString {
            components.append(urlString)
        }
        return components.joined(separator: " ")
    }
}

extension Request: CustomDebugStringConvertible {
    public var debugDescription: String {
        return cURLRepresentation()
    }
    
    func cURLRepresentation() -> String {
        var components = ["$ curl -v"]
        guard let request = self.request,
            let url = request.url,
            let host = url.host
            else { return "$ curl command could not be created" }
        if let httpMethod = request.httpMethod, httpMethod != "GET" {
            components.append("-X \(httpMethod)")
        }
        if let credentialStorage = self.session?.configuration.urlCredentialStorage {
            let protectionSpace = URLProtectionSpace(host: host, port: url.port ?? 0, protocol: url.scheme, realm: host, authenticationMethod: NSURLAuthenticationMethodHTTPBasic)
            if let credentials = credentialStorage.credentials(for: protectionSpace)?.values {
                for credential in credentials {
                    guard let user = credential.user, let password = credential.password else {
                        continue
                    }
                    components.append("-u \(user):\(password)")
                }
            } else {
                if let credential = delegate.credential, let user = credential.user, let password = credential.password {
                    components.append("-u \(user):\(password)")
                }
            }
        }
//        if session?.configuration.httpShouldSetCookies {
//            if let cookieStot
//        }
        //MARK: TODO
        return components.joined(separator: " \\\n\t")
    }
    
}


// MARK: -
///
open class DataRequest: Request {
    struct Requestable: TaskConvertible {
        
        
        func task(session: URLSession, adapter: RequestAdapter?, queue: DispatchQueue) throws -> URLSessionTask {
            do {
                let url = try self.urlRequest.adapt(using: adapter)
                return queue.sync {
                   session.dataTask(with: url)
                }
            } catch {
                throw AdaptError(error: error)
            }
        }
        
        let urlRequest: URLRequest
        
    }
    open override var request: URLRequest? {
        if let request = super.request {
            return request
        }
        if let requestable = originalTask as? Requestable {
            return requestable.urlRequest
        }
        return nil
    }
    var dataDelegate: DataTaskDelegate { return delegate as! DataTaskDelegate}
    open var progress: Progress { return dataDelegate.proress }
    @discardableResult
    open func stream(closure: ((Data) -> Void)? = nil) -> Self {
        dataDelegate.dataStream = closure
        return self
    }
    @discardableResult
    open func downloadPropress(queue: DispatchQueue = DispatchQueue.main, closure: @escaping ProspressHandler) -> Self {
        dataDelegate.progressHandler = (closure, queue) as (closure: Request.ProspressHandler, queue: DispatchQueue)
        return self
    }
}
// MARK: -
open class DownloadRequest: Request {
    
    public struct DownloadOptions: OptionSet {
        public let rawValue: UInt
        public static let createIntermediateDirectories = DownloadOptions(rawValue: 1 << 0)
        public static let removePreviousFile = DownloadOptions(rawValue: 1 << 1)
        public init(rawValue: UInt) {
            self.rawValue = rawValue
        }
    }
    
    public typealias DownloadFileDestination = (
        _ temporaryURL: URL,
        _ response: HTTPURLResponse) -> (destinationURL: URL, options: DownloadOptions)
    
    enum Downloadable: TaskConvertible {
        case request(URLRequest)
        case resumeData(Data)
        
        func task(session: URLSession, adapter: RequestAdapter?, queue: DispatchQueue) throws -> URLSessionTask {
            do {
                let task: URLSessionTask
                switch self {
                case let .request(urlRequest):
                    let urlRequest = try urlRequest.adapt(using: adapter)
                    task = queue.sync {
                        session.downloadTask(with: urlRequest)
                    }
                case let .resumeData(resumeData):
                    task = queue.sync {
                        session.downloadTask(withResumeData: resumeData)
                    }
                }
                return task
            } catch {
                throw AdaptError(error: error)
            }
        }
    }
    
    open override var request: URLRequest? {
        if let request = super.request {
            return request
        }
        if let downloadable = originalTask as? Downloadable, case let .request(urlRequest) = downloadable {
            return urlRequest
        }
        return nil
    }
    
    var downloadDelegate: DownloadTaskDelegate {
        return delegate as! DownloadTaskDelegate
    }
    
    open var resumeData: Data? { return downloadDelegate.resumeData }
    
    open var propress: Progress {
        return downloadDelegate.propress
    }
    
    open override func cancel() {
        downloadDelegate.downloadTask.cancel { (data) in
            self.downloadDelegate.resumeData = data
        }
        NotificationCenter.default.post(name: Notification.Name.Task.DidCancel, object: self, userInfo: [Notification.Key.Task: task as Any])
    }
    @discardableResult
    open func downloadPropress(queue: DispatchQueue = DispatchQueue.main, closure: @escaping ProspressHandler) -> Self {
        downloadDelegate.propressHandler = (closure, queue) as (closure: Request.ProspressHandler, queue: DispatchQueue)
        return self
    }
    
    open class func suggestDownloadDestination(for directory: FileManager.SearchPathDirectory = .documentDirectory, in domin: FileManager.SearchPathDomainMask = .userDomainMask) -> DownloadFileDestination {
        return { temporaryURL, response in
            let directoryURLs = FileManager.default.urls(for: directory, in: domin)
            if !directoryURLs.isEmpty {
                return (directoryURLs[0].appendingPathComponent(response.suggestedFilename!), [])
            }
            return (temporaryURL, [])
        }
    }
    
}

//MARK: -
open class UploadRequest: DataRequest {
    enum Uploadable: TaskConvertible {
        func task(session: URLSession, adapter: RequestAdapter?, queue: DispatchQueue) throws -> URLSessionTask {
            do {
                let task: URLSessionTask
                switch self {
                case let .data(data, urlRequest):
                    let urlRequest = try urlRequest.adapt(using: adapter)
                    task = queue.sync {
                        session.uploadTask(with: urlRequest, from: data)
                    }
                case let .file(url, urlRequest):
                    let urlRequest = try urlRequest.adapt(using: adapter)
                    task = queue.sync {
                        session.uploadTask(with: urlRequest, fromFile: url)
                    }
                case let .stream(_, urlRequest):
                    let urlRequest = try urlRequest.adapt(using: adapter)
                    task = queue.sync {
                        session.uploadTask(withStreamedRequest: urlRequest)
                    }
                }
                return task
            } catch  {
                throw AdaptError(error: error)
            }
        }
        
        case data(Data, URLRequest)
        case file(URL, URLRequest)
        case stream(InputStream, URLRequest)
        
    }
    open override var request: URLRequest? {
        if let request = super.request {
            return request
        }
        guard let uploadble = originalTask as? Uploadable else { return nil }
        switch uploadble {
        case .data(_, let urlRequest):
            return urlRequest
        case .file(_, let urlRequest):
            return urlRequest
        case .stream(_, let urlRequest):
            return urlRequest
        }
    }
    var uploadDelegate: UploadTaskDelegate { return delegate as! UploadTaskDelegate}
    open var uploadPropress: Progress { return uploadDelegate.uploadPropress }
    //MARK: upload Propress
    @discardableResult
    open func uploadPropress(queue: DispatchQueue = DispatchQueue.main, closure: @escaping ProspressHandler) -> Self {
        uploadDelegate.uploadPropressHandler = (closure, queue) as (closure: Request.ProspressHandler, queue: DispatchQueue)
        return self
    }
    
}


