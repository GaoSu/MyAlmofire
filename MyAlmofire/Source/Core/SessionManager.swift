//
//  SessionManager.swift
//  MyAlmofire
//
//  Created by 刘 on 2018/10/30.
//  Copyright © 2018年 刘航. All rights reserved.
//

import Foundation

open class SessionManager{
    
    public enum MultipartFormDataEncodingResult {
        case success(request: UploadRequest, streamingFromDisk: Bool, streamFileURL: URL?)
        case failure(Error)
    }
    
    public static let defaultHTTPHeaders: HTTPHeaders = {
        let acceptEncoding: String = "gzip;q=1.0, compress;q=0.5"
        let acceptLanguage = Locale.preferredLanguages.prefix(6).enumerated().map({ (index, languageCode) -> String in
            let quality = 1.0 - (Double(index) * 0.1)
            return "\(languageCode);q=\(quality)"
        }).joined(separator: ", ")
        let userAgent: String = {
            if let info = Bundle.main.infoDictionary {
                let executable = info[kCFBundleExecutableKey as String] as? String ?? "Unknown"
                let bundle = info[kCFBundleIdentifierKey as String] as? String ?? "Unknown"
                let appVersion = info["CFBundleShortVersionString"] as? String ?? "Unknown"
                let appBuild = info[kCFBundleVersionKey as String] as? String ?? "Unknown"
                
                let osNameVersion: String = {
                    let version = ProcessInfo.processInfo.operatingSystemVersion
                    let versionString = "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
                    
                    let osName: String = {
                        #if os(iOS)
                        return "iOS"
                        #elseif os(watchOS)
                        return "watchOS"
                        #elseif os(tvOS)
                        return "tvOS"
                        #elseif os(macOS)
                        return "OS X"
                        #elseif os(Linux)
                        return "Linux"
                        #else
                        return "Unknown"
                        #endif
                    }()
                    
                    return "\(osName) \(versionString)"
                }()
                
                let alamofireVersion: String = {
                    guard
                        let afInfo = Bundle(for: SessionManager.self).infoDictionary,
                        let build = afInfo["CFBundleShortVersionString"]
                        else { return "Unknown" }
                    
                    return "Alamofire/\(build)"
                }()
                
                return "\(executable)/\(appVersion) (\(bundle); build:\(appBuild); \(osNameVersion)) \(alamofireVersion)"
            }
            
            return "Alamofire"
        }()
        return [
            "Accept-Encoding": acceptEncoding,
            "Accept-Language": acceptLanguage,
            "User-Agent": userAgent
        ]
    }()
    
    public static let `default`: SessionManager = {
       let configuration = URLSessionConfiguration.default
        configuration.httpAdditionalHeaders = SessionManager.defaultHTTPHeaders
        //MARK: TODO
        return SessionManager()
    }()
    
    public static let multipartFormDataEncodingMemoryThreshold: UInt64 = 10_000_000
    
    public let session: URLSession
    
    public let delegate: SessionDelegate
    
    open var startRequestImmediately: Bool = true
    
    open var adapter: RequestAdapter?
    
    open var retrier: RequestRetrier? {
        get { return delegate.retrier }
        set { delegate.retrier = newValue}
    }
    
    open var backgroundCompletionHandler: (() -> Void)?
    
    let queue = DispatchQueue(label: "org.alamofire.session-manager." + UUID().uuidString)
    
    
    //MARK: Lifecycle
    //抽取的共同方法
    private func commonInit(serverTrustPolicyManager: ServerTrustPolicyManager?) {
        session.serverTrustPolicyManager = serverTrustPolicyManager
        delegate.sessionManager = self
        delegate.sessionDidFinishEventsForBackgroundURLSession = { [weak self] session in
            guard let strongSelf = self else { return }
            DispatchQueue.main.async {
                strongSelf.backgroundCompletionHandler?()
            }
        }
    }
    
    public init(configuration: URLSessionConfiguration = URLSessionConfiguration.default, delegate: SessionDelegate = SessionDelegate(), serverTrustPolicyManager: ServerTrustPolicyManager? = nil) {
        self.delegate = delegate
        self.session = URLSession(configuration: configuration, delegate: delegate as URLSessionDelegate, delegateQueue: nil)
        commonInit(serverTrustPolicyManager: serverTrustPolicyManager)
    }
    
    public init? (session: URLSession, delegate: SessionDelegate, serverTrustPolicyManager: ServerTrustPolicyManager? = nil) {
        guard delegate === session.delegate else {
            return nil
        }
        self.delegate = delegate
        self.session = session
        commonInit(serverTrustPolicyManager: serverTrustPolicyManager)
    }
    deinit {
        session.invalidateAndCancel()
    }
    //MARK - Data Request
    // @discardableResult 的作用不接受返回值也可以
    
    @discardableResult
    open func request(_ urlRequest: URLRequestConvertible) -> DataRequest {
        var originalRequest: URLRequest?
        do {
            originalRequest = try urlRequest.asURLRequest()
            let originalTask = DataRequest.Requestable(urlRequest: originalRequest!)
            let task = try originalTask.task(session: session, adapter: adapter, queue: queue)
            let request = DataRequest(session: session, requestTask: .data(originalTask, task), error: nil)
            
            delegate[task] = request
            if startRequestImmediately {
               request.resume()
            }
            return request
        } catch {
            return request(originalRequest, failedWith: error)
        }
    }
    
    private func request(_ urlRequest: URLRequest?, failedWith error: Error) -> DataRequest {
        var requestTask: Request.RequestTask = .data(nil, nil)
        if let urlRequest = urlRequest {
            let originalTask = DataRequest.Requestable(urlRequest: urlRequest)
            requestTask = .data(originalTask, nil)
        }
        let underlyingError = error.underlyingAdaptError ?? error
        let request = DataRequest(session: session, requestTask: requestTask, error: underlyingError)
        if let retrier = retrier, error is AdaptError {
            //MARK: TODO 重新尝试
        } else {
            if startRequestImmediately { request.resume() }
        }
        return request
    }
    
    @discardableResult
    open func request(_ url: URLConvertible, method: HTTPMethod = .get, parameters: Parameters? = nil, encoding: ParameterEncoding = URLEncoding.default, headers: HTTPHeaders? = nil) -> DataRequest {
        var originalRequest: URLRequest?
        do {
            originalRequest = try URLRequest(url: url, method: method, headers: headers)
            let encodeURLRequest = try encoding.encode(originalRequest!, with: parameters)
            return request(encodeURLRequest)
        } catch {
            return request(originalRequest, failedWith: error)
        }
    }
    
    @discardableResult
    open func download(_ url: URLConvertible, method: HTTPMethod = .get, parameters: Parameters? = nil, encoding: ParameterEncoding = URLEncoding.default, headers: HTTPHeaders? = nil, to destination: DownloadRequest.DownloadFileDestination? = nil) -> DownloadRequest {
        do {
            let urlRequest = try URLRequest(url: url, method: method, headers: headers)
            let encodedURLRequest = try encoding.encode(urlRequest, with: parameters)
            return download(encodedURLRequest, to: destination)
        } catch  {
            return download(nil, to: destination, failedWith: error)
        }
    }
    
    @discardableResult
    open func download(_ urlRequest: URLRequestConvertible, to destination: DownloadRequest.DownloadFileDestination? = nil) -> DownloadRequest {
        do {
            let urlRequest = try urlRequest.asURLRequest()
            return download(.request(urlRequest), to: destination)
        } catch {
            return download(nil, to: destination, failedWith: error)
        }
    }
    
    private func download(_ downloadable: DownloadRequest.Downloadable, to destination: DownloadRequest.DownloadFileDestination?) -> DownloadRequest {
        do {
            let task = try downloadable.task(session: session, adapter: adapter, queue: queue)
            let download = DownloadRequest(session: session, requestTask: .download(downloadable, task), error: nil)
            download.downloadDelegate.destination = destination
            delegate[task] = download
            if startRequestImmediately {
                download.resume()
            }
            return download
        } catch  {
            return download(downloadable, to: destination, failedWith: error)
        }
    }
    private func download(_ downloadable: DownloadRequest.Downloadable?, to destination: DownloadRequest.DownloadFileDestination?, failedWith error: Error) -> DownloadRequest {
        var downloadTask: Request.RequestTask = .download(nil, nil)
        if let downloadable = downloadable {
            downloadTask = .download(downloadable, nil)
        }
        let underlyingError = error.underlyingAdaptError ?? error
        let download = DownloadRequest(session: session, requestTask: downloadTask, error: underlyingError)
        download.downloadDelegate.destination = destination
        if let retrier = retrier, error is AdaptError {
            //
        } else {
            if startRequestImmediately { download.resume() }
        }
        return download
    }
}
