//
//  NetworkReachabilityManager.swift
//  MyAlmofire
//
//  Created by mini on 2019/6/27.
//  Copyright © 2019 刘航. All rights reserved.
//
#if !os(watchOS)
import Foundation
import SystemConfiguration

open class NetworkReachbilityManager {
    
    public enum ConnectionType {
        case ethernetOrWiFi
        case wwan
    }
    
    public enum NetworkReachabilityStatus {
        case unknown
        case notReachable
        case reachable(ConnectionType)
    }
    
    public typealias Listener = (NetworkReachabilityStatus) -> Void
    
    open var listenerQueue: DispatchQueue = DispatchQueue.main
    open var listener: Listener?
    open var isReachable: Bool {
        return isReachableOnWWAN || isReachableOnEtheernetOrWiFi
    }
    
    open var isReachableOnWWAN: Bool {
        return networkReachabilityStatus == .reachable(.wwan)
    }
    
    open var isReachableOnEtheernetOrWiFi: Bool {
        return networkReachabilityStatus == .reachable(.ethernetOrWiFi)
    }
    open var networkReachabilityStatus: NetworkReachabilityStatus {
        guard let flags = self.flags else { return .unknown }
        return networkReachablityStatusForFlags(flags)
    }
    
    open var flags: SCNetworkReachabilityFlags? {
        var flags = SCNetworkReachabilityFlags()
        if SCNetworkReachabilityGetFlags(reachability, &flags) {
            return flags
        }
        return nil
    }
    
    private let reachability: SCNetworkReachability
    open var perviousFlags: SCNetworkReachabilityFlags
    
    
    public convenience init?(host: String) {
        guard let reachability = SCNetworkReachabilityCreateWithName(nil, host) else { return nil }
        self.init(reachability: reachability)
    }
    
    public convenience init?() {
        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        guard let reachability = withUnsafePointer(to: &address, { pointer in
            return pointer.withMemoryRebound(to: sockaddr.self, capacity: MemoryLayout<sockaddr>.size) {
                return SCNetworkReachabilityCreateWithAddress(nil, $0)
            }
        }) else { return nil }
        self.init(reachability: reachability)
    }
    
    private init(reachability: SCNetworkReachability) {
        self.reachability = reachability
        self.perviousFlags = SCNetworkReachabilityFlags()
    }
    
    deinit {
        stopListening()
    }
    
    @discardableResult
    open func startListening() -> Bool {
        var context = SCNetworkReachabilityContext(version: 0, info: nil, retain: nil, release: nil, copyDescription: nil)
        context.info = Unmanaged.passRetained(self).toOpaque()
        let callbackEnabled = SCNetworkReachabilitySetCallback(reachability, {(_, flags, info) in
            let reachability = Unmanaged<NetworkReachbilityManager>.fromOpaque(info!).takeUnretainedValue()
            reachability.notifyListener(flags)
        }, &context)
        let queueEnabled = SCNetworkReachabilitySetDispatchQueue(reachability, listenerQueue)
        listenerQueue.async {
            self.perviousFlags = SCNetworkReachabilityFlags()
            self.notifyListener(self.flags ?? SCNetworkReachabilityFlags())
        }
        return callbackEnabled && queueEnabled
    }
    
    open func stopListening() {
        SCNetworkReachabilitySetCallback(reachability, nil, nil)
        SCNetworkReachabilitySetDispatchQueue(reachability, nil)
    }
    
    func notifyListener(_ flags: SCNetworkReachabilityFlags) {
        guard perviousFlags != flags else {
            return
        }
        perviousFlags = flags
        listener?(networkReachablityStatusForFlags(flags))
    }
    
    func networkReachablityStatusForFlags(_ flags: SCNetworkReachabilityFlags) -> NetworkReachabilityStatus {
        guard isNetworkReachable(with: flags) else {
            return .notReachable
        }
        var networkStatus: NetworkReachabilityStatus = .reachable(.ethernetOrWiFi)
        #if os(iOS)
        if flags.contains(.isWWAN) {
            networkStatus = .reachable(.wwan)
        }
        #endif
        return networkStatus
    }
    
    
    func isNetworkReachable(with flags: SCNetworkReachabilityFlags) -> Bool {
        let isReachable = flags.contains(.reachable)
        let needsConnection = flags.contains(.connectionRequired)
        let canConnectAutomatically = flags.contains(.connectionOnDemand) || flags.contains(.connectionOnTraffic)
        let canConnectWithoutUserIneraction = canConnectAutomatically && !flags.contains(.interventionRequired)
        return isReachable && (!needsConnection || canConnectWithoutUserIneraction)
    }
}


//MARK: -
extension NetworkReachbilityManager.NetworkReachabilityStatus: Equatable {}

public func ==(lhs: NetworkReachbilityManager.NetworkReachabilityStatus, rhs: NetworkReachbilityManager.NetworkReachabilityStatus) -> Bool {
    switch (lhs, rhs) {
    case (.unknown, .unknown):
        return true
    case (.notReachable, .notReachable):
        return true
    case let (.reachable(lhsConnectionType), .reachable(rhsConnectionType)):
        return lhsConnectionType == rhsConnectionType
    default:
        return false
    }
}

#endif
