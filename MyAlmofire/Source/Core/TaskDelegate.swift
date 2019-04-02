//
//  TaskDelegate.swift
//  MyAlmofire
//
//  Created by 刘 on 2018/10/30.
//  Copyright © 2018年 刘航. All rights reserved.
//

import Foundation

open class TaskDelegate:NSObject{
    
    public let queue: OperationQueue?
    
    private var error: Error?
    private var initialResposeTime: CFAbsoluteTime?
    
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
    
    func reset(){
        error = nil
        initialResposeTime = nil
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
}

class DataTaskDelegate: TaskDelegate,URLSessionDataDelegate {
    var dataTask : URLSessionDataTask{ return task as! URLSessionDataTask}
    
    var dataStream: ((_ data: Data) -> Void)?
    
    var proress: Progress?
    
    var data: Data? {
        if dataStream != nil{
            return nil
        }else{
            return mutableData
        }
    }
    
    private var mutableData: Data?
    
    var progressHandler: (closure: Request.ProspressHandler,queue: DispatchQueue)?
    
    private var expectedContenLength: Int64 = 0
    
    private var totalBytesReceived: Int64 = 0
    
    override init(task: URLSessionTask?) {
        mutableData = Data()
        proress = Progress(totalUnitCount: 0)
        super.init(task:task)
    }
    
    
}
