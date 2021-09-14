//
//  File.swift
//  File
//
//  Created by Morten Bek Ditlevsen on 14/09/2021.
//

import Foundation

@objc public class FRepoInfo: NSObject, NSCopying {
    public func copy(with zone: NSZone? = nil) -> Any {
        self
    }

    /// The host that the database should connect to.
    @objc public let host: String

    @objc public let namespace: String
    @objc public var internalHost: String {
        didSet {
            if internalHost != oldValue {
                let internalHostKey = "firebase:host:\(host)"
                UserDefaults.standard.set(internalHost, forKey: internalHostKey)
            }
        }
    }
    public var secure: Bool
    public let domain: String

    @objc public init(host: String, isSecure: Bool, withNamespace namespace: String) {
        self.host = host
        self.namespace = namespace
        self.secure = isSecure
        if let index = host.firstIndex(of: ".") {
            let after = host.index(after: index)
            self.domain = String(host[after...])
        } else {
            self.domain = host
        }
        let internalHostKey = "firebase:host:\(host)"
        if let cachedInternalHost = UserDefaults.standard.string(forKey: internalHostKey) {
            self.internalHost = cachedInternalHost
        } else {
            self.internalHost = host
        }
    }

    public override var description: String {
        return "http\(secure ? "s" : ""):\(host)"
    }

    @objc public convenience init(info: FRepoInfo, emulatedHost: String) {
        self.init(host: emulatedHost, isSecure: false, withNamespace: info.namespace)
    }

    @objc public func connectionURL(lastSessionID: String?) -> String {
        let scheme: String
        if secure {
            scheme = "wss"
        } else {
            scheme = "ws"
        }
        var url = "\(scheme)://\(internalHost)/.ws?\(kWireProtocolVersionParam)=\(kWebsocketProtocolVersion)&ns=\(namespace)"

        if let lastSessionID = lastSessionID {
            url += "&ls=\(lastSessionID)"
        }
        return url
    }

    @objc public var connectionURL: String {
        connectionURL(lastSessionID: nil)
    }

    @objc public func clearInternalHostCache() {
        // Remove the cached entry
        self.internalHost = self.host
        let internalHostKey = "firebase:host:\(host)"
        UserDefaults.standard.removeObject(forKey: internalHostKey)
    }

    public var isDemoHost: Bool {
        domain == "firebaseio-demo.com"
    }

    @objc public var isCustomHost: Bool {
        domain != "firebaseio-demo.com" &&
        domain != "firebaseio.com"
    }
}
