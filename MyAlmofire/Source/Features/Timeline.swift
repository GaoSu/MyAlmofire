//
//  Timeline.swift
//  MyAlmofire
//
//  Created by mini on 2019/6/24.
//  Copyright © 2019 刘航. All rights reserved.
//

import Foundation

public struct Timeline {
    public let requestStartTime: CFAbsoluteTime
    public let initialResponseTime: CFAbsoluteTime
    public let requestCompletedTime: CFAbsoluteTime
    public let serialzationCompletedTime: CFAbsoluteTime
    
    public let latency: TimeInterval
    public let requestDuration: TimeInterval
    
    public let serializationDuration: TimeInterval
    
    public let totalDuration: TimeInterval
    
    public init (requestStartTime: CFAbsoluteTime = 0.0, initialResponseTime: CFAbsoluteTime = 0.0, requestCompletedTime: CFAbsoluteTime = 0.0, serializationCompletedTime: CFAbsoluteTime = 0.0) {
        self.requestStartTime = requestStartTime
        self.initialResponseTime = initialResponseTime
        self.requestCompletedTime = requestCompletedTime
        self.serialzationCompletedTime = serializationCompletedTime
        self.latency = initialResponseTime - requestStartTime
        self.requestDuration = requestCompletedTime - requestStartTime
        self.serializationDuration = serializationCompletedTime - requestCompletedTime
        self.totalDuration = serializationCompletedTime - requestStartTime
    }
}

extension Timeline: CustomStringConvertible {
    public var description: String {
        let latency = String(format: "%.3f", self.latency)
        let requestDuration = String(format: "%.3f", self.requestDuration)
        let serializationDuration = String(format: "%.3f", self.serializationDuration)
        let totalDuration = String(format: "%.3f", self.totalDuration)
        
        // NOTE: Had to move to string concatenation due to memory leak filed as rdar://26761490. Once memory leak is
        // fixed, we should move back to string interpolation by reverting commit 7d4a43b1.
        let timings = [
            "\"Latency\": " + latency + " secs",
            "\"Request Duration\": " + requestDuration + " secs",
            "\"Serialization Duration\": " + serializationDuration + " secs",
            "\"Total Duration\": " + totalDuration + " secs"
        ]
        
        return "Timeline: { " + timings.joined(separator: ", ") + " }"
    }
}

extension Timeline: CustomDebugStringConvertible {
    public var debugDescription: String {
        let requestStartTime = String(format: "%.3f", self.requestStartTime)
        let initialResponseTime = String(format: "%.3f", self.initialResponseTime)
        let requestCompletedTime = String(format: "%.3f", self.requestCompletedTime)
        let serializationCompletedTime = String(format: "%.3f", self.serialzationCompletedTime)
        let latency = String(format: "%.3f", self.latency)
        let requestDuration = String(format: "%.3f", self.requestDuration)
        let serializationDuration = String(format: "%.3f", self.serializationDuration)
        let totalDuration = String(format: "%.3f", self.totalDuration)
        
        // NOTE: Had to move to string concatenation due to memory leak filed as rdar://26761490. Once memory leak is
        // fixed, we should move back to string interpolation by reverting commit 7d4a43b1.
        let timings = [
            "\"Request Start Time\": " + requestStartTime,
            "\"Initial Response Time\": " + initialResponseTime,
            "\"Request Completed Time\": " + requestCompletedTime,
            "\"Serialization Completed Time\": " + serializationCompletedTime,
            "\"Latency\": " + latency + " secs",
            "\"Request Duration\": " + requestDuration + " secs",
            "\"Serialization Duration\": " + serializationDuration + " secs",
            "\"Total Duration\": " + totalDuration + " secs"
        ]
        
        return "Timeline: { " + timings.joined(separator: ", ") + " }"
    }
    
    
}
