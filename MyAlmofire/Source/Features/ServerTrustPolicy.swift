//
//  ServerTrustPolicy.swift
//  MyAlmofire
//
//  Created by mini on 2019/6/20.
//  Copyright © 2019 刘航. All rights reserved.
//

import Foundation

open class ServerTrustPolicyManager {
//    public let policies: [String: ServerTrustPolicyManager]
}

//MARK: -
extension URLSession {
    private struct AssociatedKeys {
        static var managerKey = "URLSession.ServerTrustPolicyManager"
    }
    var serverTrustPolicyManager: ServerTrustPolicyManager? {
        get {
            return objc_getAssociatedObject(self, &AssociatedKeys.managerKey) as? ServerTrustPolicyManager
        }
        set(manager) {
            objc_setAssociatedObject(self, &AssociatedKeys.managerKey, manager, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}

public enum ServerTrustPolicy {
    case performDefaultEvalation(validateHost: Bool)
    case performRevokedEvalation(validateHost: Bool, revocationFlags: CFOptionFlags)
    case pinCertificates(certificates: [SecCertificate], validateCertificateChain: Bool, validateHost: Bool)
    case pinPublicKeys(publicKeys: [SecKey], validateCertificateChain: Bool, validateHost: Bool)
    case disableEvaluation
    case customEvaluation((_ serverTrust: SecTrust, _ host: String) -> Bool)
    
    private func trustIsValid(_ trust: SecTrust) -> Bool {
        var isValid = false
        var result = SecTrustResultType.invalid
        let status = SecTrustEvaluate(trust, &result)
        if status == errSecSuccess {
            let unspecified = SecTrustResultType.unspecified
            let proceed = SecTrustResultType.proceed
            isValid = result == unspecified || result == proceed
        }
        return isValid
    }
    
    
    
    private func certificateData(for trust: SecTrust) -> [Data] {
        var certificates: [SecCertificate] = []
        for index in 0..<SecTrustGetCertificateCount(trust) {
            if let certificate = SecTrustGetCertificateAtIndex(trust, index) {
                certificates.append(certificate)
            }
        }
        return certificateData(for: certificates)
    }
    
    private func certificateData(for certificates: [SecCertificate]) -> [Data] {
        return certificates.map({SecCertificateCopyData($0) as Data})
    }
    
    private static func publicKey(for trust: SecTrust) -> [SecKey] {
        var publicKeys: [SecKey] = []
        for index in 0..<SecTrustGetCertificateCount(trust) {
            if let certificate = SecTrustGetCertificateAtIndex(trust, index),
                let publicKey = publickey(for: certificate) {
                publicKeys.append(publicKey)
            }
        }
        return publicKeys
    }
    
    private static func publickey(for certificate: SecCertificate) -> SecKey? {
        var publicKey: SecKey?
        let policy = SecPolicyCreateBasicX509()
        var trust: SecTrust?
        let trustCreationStatus = SecTrustCreateWithCertificates(certificate, policy, &trust)
        if let trust = trust, trustCreationStatus == errSecSuccess {
            publicKey = SecTrustCopyPublicKey(trust)
        }
        return publicKey
    }
    
}
