//
//  TaskDelegate.swift
//  MyAlmofire
//
//  Created by 刘 on 2018/10/30.
//  Copyright © 2018年 刘航. All rights reserved.
//

import Foundation

open class TaskDelegate: NSObject{
    
    public let queue: OperationQueue?
    
    var error: Error?
    var initialResponseTime: CFAbsoluteTime?
    
    private let taskLock = NSLock()
    private var _task: URLSessionTask? {
        didSet{ reset() }
    }
    var task: URLSessionTask? {
        set {
            taskLock.lock(); defer {taskLock.unlock()}
            _task = newValue
        }
        get {
            taskLock.lock(); defer {taskLock.unlock()}
            return _task
        }
    }
    
    var credential: URLCredential?
    
    
    func reset(){
        error = nil
        initialResponseTime = nil
    }
    
    init(task: URLSessionTask?){
        _task = task
        self.queue = {
            let operationQueue = OperationQueue()
            operationQueue.maxConcurrentOperationCount = 1
            operationQueue.isSuspended = true
            operationQueue.qualityOfService = .utility
            return operationQueue
        }()
    }
    //MARK: URLSeesionTaskDelegate
    var taskWillPerformHTTPRedirection: ((URLSession, URLSessionTask, HTTPURLResponse, URLRequest) -> URLRequest?)?
    var taskDidReceiveChallenge: ((URLSession, URLSessionTask, URLAuthenticationChallenge) -> (URLSession.AuthChallengeDisposition, URLCredential?))?
    var taskNeedNewBodyStream: ((URLSession, URLSessionTask) -> InputStream?)?
    var taskDidCompleteWithError: ((URLSession, URLSessionTask, Error?) -> Void)?

    @objc(URLSession:task:willPerformHTTPRedirection:newRequest:completionHandler:)
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void)  {
        var redirectRequest: URLRequest? = request
        if let taskWillPerformHTTPRedirection = taskWillPerformHTTPRedirection {
            redirectRequest = taskWillPerformHTTPRedirection(session, task, response, request)
        }
        completionHandler(redirectRequest)
    }
    
    func urlSeesion(_ session: URLSession, task: URLSessionTask, didReceive chllenge: URLAuthenticationChallenge, completionHandler: (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        var dispostion: URLSession.AuthChallengeDisposition = .performDefaultHandling
        var credential: URLCredential?
        if let taskDidReceiveChallenge = taskDidReceiveChallenge {
            (dispostion, credential) = taskDidReceiveChallenge(session, task, chllenge)
        } else if chllenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            let host = chllenge.protectionSpace.host
//            if let serverÔTrustPolicy =
        }
      completionHandler(dispostion, credential)
    }
}

class DataTaskDelegate: TaskDelegate,URLSessionDataDelegate {
    var dataTask : URLSessionDataTask{ return task as! URLSessionDataTask}
    
    var dataStream: ((_ data: Data) -> Void)?
    
    var proress: Progress
    
    var data: Data? {
        if dataStream != nil{
            return nil
        }else{
            return mutableData
        }
    }
    
    private var mutableData: Data?
    
    var progressHandler: (closure: Request.ProspressHandler, queue: DispatchQueue)?
    
    private var expectedContenLength: Int64 = 0
    
    private var totalBytesReceived: Int64 = 0
    
    private var expectedContenLenth: Int64?
    
    override init(task: URLSessionTask?) {
        mutableData = Data()
        proress = Progress(totalUnitCount: 0)
        super.init(task:task)
    }
    
    override func reset() {
        super.reset()
        proress = Progress(totalUnitCount: 0)
        totalBytesReceived = 0
        mutableData = Data()
        expectedContenLength = 0
    }
    //MARK:URLSeesionDataDelegate
    var dataTaskDidReceiveResponse: ((URLSession, URLSessionDataTask, URLResponse) -> URLSession.ResponseDisposition)?
    var dataTaskDidBecomeDownloadTask: ((URLSession, URLSessionDataTask, URLSessionDownloadTask) -> Void)?
    var dataTaskDidReceiveData: ((URLSession, URLSessionDataTask, Data) -> Void)?
    var dataTaskWillCacheResponse: ((URLSession, URLSessionDataTask, CachedURLResponse) -> CachedURLResponse?)?
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        var disposition: URLSession.ResponseDisposition = .allow
        expectedContenLength = response.expectedContentLength
        if let dataTaskDidReceiveResponse = dataTaskDidReceiveResponse {
            disposition = dataTaskDidReceiveResponse(session, dataTask, response)
        }
        completionHandler(disposition)
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didBecome downloadTask: URLSessionDownloadTask) {
        dataTaskDidBecomeDownloadTask?(session, dataTask, downloadTask)
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        if initialResponseTime == nil {
            initialResponseTime = CFAbsoluteTimeGetCurrent()
        }
        if let dataTaskDidReceiveData = dataTaskDidReceiveData {
            dataTaskDidReceiveData(session, dataTask, data)
        } else {
            if let dataStream = dataStream {
                dataStream(data)
            } else {
                mutableData?.append(data)
            }
            
            let byteReceived = Int64(data.count)
            totalBytesReceived += byteReceived
            let totalBytesExpected = dataTask.response?.expectedContentLength ?? NSURLSessionTransferSizeUnknown
            proress.totalUnitCount = totalBytesExpected
            proress.completedUnitCount = totalBytesReceived
            if let progressHandler = progressHandler {
                progressHandler.queue.async {
                    progressHandler.closure(self.proress)
                }
            }
        }
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, willCacheResponse proposedResponse: CachedURLResponse, completionHandler: @escaping (CachedURLResponse?) -> Void) {
        var cachedResponse: CachedURLResponse? = proposedResponse
        if let dataTaskWillCacheResponse = dataTaskWillCacheResponse {
            cachedResponse = dataTaskWillCacheResponse(session, dataTask, proposedResponse)
        }
        completionHandler(cachedResponse)
    }
    
}

//MARK: -

class DownloadTaskDelegate: TaskDelegate, URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
       temporaryURL = location
        guard let destination = destination, let response = downloadTask.response as? HTTPURLResponse else { return }
        let result = destination(location, response)
        let destinationURL = result.destinationURL
        let options = result.options
        self.destinationURL = destinationURL
        do {
            if options.contains(.removePreviousFile), FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            if options.contains(.createIntermediateDirectories) {
                let directory = destinationURL.deletingLastPathComponent()
               try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
            }
            try FileManager.default.moveItem(at: location, to: destinationURL)
        } catch {
            self.error = error
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        if initialResponseTime == nil {
            initialResponseTime = CFAbsoluteTimeGetCurrent()
        }
        if let downloadTaskDidWriteData = downloadTaskDidWriteData {
            downloadTaskDidWriteData((session, downloadTask, bytesWritten, totalBytesWritten, totalBytesExpectedToWrite))
        } else {
            propress.totalUnitCount = totalBytesExpectedToWrite
            propress.completedUnitCount = totalBytesWritten
            if let progressHandler = propressHandler {
                propressHandler?.queue.async {
                    progressHandler.closure(self.propress)
                }
            }
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didResumeAtOffset fileOffset: Int64, expectedTotalBytes: Int64) {
        if let downloadTaskDidResumeAtOffset = downloadTaskDidResumeAtOffset {
            downloadTaskDidResumeAtOffset((session, downloadTask, fileOffset, expectedTotalBytes))
        } else {
          propress.totalUnitCount = expectedTotalBytes
            propress.completedUnitCount = fileOffset
        }
    }
    
    //MARK: properties
    var downloadTask: URLSessionDownloadTask { return task as! URLSessionDownloadTask }
    
    var propress: Progress
    var propressHandler: (closure: Request.ProspressHandler, queue: DispatchQueue)?
    
    var resumeData: Data?
    var data: Data? { return resumeData }
    var destination: DownloadRequest.DownloadFileDestination?
    var temporaryURL: URL?
    var destinationURL: URL?
    var fileURL: URL? { return destination != nil ? destinationURL : temporaryURL }
    override init(task: URLSessionTask?) {
        propress = Progress(totalUnitCount: 0)
        super.init(task: task)
    }
    override func reset() {
        super.reset()
        propress = Progress(totalUnitCount: 0)
        resumeData = nil
    }
    
    var downloadTaskDidFinishDownloadingToURL: ((URLSession, URLSessionDownloadTask, URL) -> URL)?
    var downloadTaskDidWriteData: (((URLSession, URLSessionDownloadTask, Int64, Int64, Int64)) -> Void)?
    var downloadTaskDidResumeAtOffset: (((URLSession, URLSessionDownloadTask, Int64, Int64)) -> Void)?
    
}

//MARK: -
class UploadTaskDelegate: DataTaskDelegate {
    var uploadTask: URLSessionUploadTask { return task as! URLSessionUploadTask}
    var uploadPropress: Progress
    var uploadPropressHandler: (closure: Request.ProspressHandler, queue: DispatchQueue)?
    //MARK: Lifecycle
    override init(task: URLSessionTask?) {
        uploadPropress = Progress(totalUnitCount: 0)
        super.init(task: task)
    }
    override func reset() {
        super.reset()
        uploadPropress = Progress(totalUnitCount: 0)
    }
    //MARK: URLSessionTaskDelegate
    var taskDidSendBodyData: ((URLSession, URLSessionTask, Int64, Int64, Int64) -> Void)?
    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        if initialResponseTime == nil {
            initialResponseTime = CFAbsoluteTimeGetCurrent()
        }
        if let taskDidSendBodyData = taskDidSendBodyData {
            taskDidSendBodyData(session, task, bytesSent, totalBytesSent, totalBytesExpectedToSend)
        } else {
            uploadPropress.totalUnitCount = totalBytesExpectedToSend
            uploadPropress.completedUnitCount = totalBytesSent
            if uploadPropressHandler != nil {
                uploadPropressHandler?.queue.async {
                    self.uploadPropressHandler?.closure(self.uploadPropress)
                }
            }
        }
    }
        
}


