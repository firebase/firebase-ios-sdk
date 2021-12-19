//
//  RemoteConfig+Subscripts.swift
//  RemoteConfigSwift
//
//  Created by 伊藤史 on 2020/08/21.
//  Copyright © 2020 Fumito Ito. All rights reserved.
//

import Foundation
import FirebaseRemoteConfig

public extension RemoteConfigAdapter {

    subscript<T: RemoteConfigSerializable>(key: RemoteConfigKey<T>) -> T.T where T: OptionalType, T.T == T {
        get {
            return self.remoteConfig[key]
        }
    }

    subscript<T: RemoteConfigSerializable>(key: RemoteConfigKey<T>) -> T.T where T.T == T {
        get {
            return self.remoteConfig[key]
        }
    }

    subscript<T: RemoteConfigSerializable>(keyPath: KeyPath<KeyStore, RemoteConfigKey<T>>) -> T.T where T: OptionalType, T.T == T {
        get {
            return self.remoteConfig[self.keyStore[keyPath: keyPath]]
        }
    }

    subscript<T: RemoteConfigSerializable>(keyPath: KeyPath<KeyStore, RemoteConfigKey<T>>) -> T.T where T.T == T {
        get {
            return self.remoteConfig[self.keyStore[keyPath: keyPath]]
        }
    }

    subscript<T: RemoteConfigSerializable>(dynamicMember keyPath: KeyPath<KeyStore, RemoteConfigKey<T>>) -> T.T where T: OptionalType, T.T == T {
        get {
            return self[keyPath]
        }
    }

    subscript<T: RemoteConfigSerializable>(dynamicMember keyPath: KeyPath<KeyStore, RemoteConfigKey<T>>) -> T.T where T.T == T {
        get {
            return self[keyPath]
        }
    }
}

public extension RemoteConfig {

    subscript<T: RemoteConfigSerializable>(key: RemoteConfigKey<T>) -> T.T where T: OptionalType, T.T == T {
        get {
            if let value = T._remoteConfig.get(key: key._key, remoteConfig: self), let _value = value as? T.T.Wrapped {
                return _value as! T
            } else if let defaultValue = key.defaultValue {
                return defaultValue
            } else {
                return T.T.empty
            }
        }
    }

    subscript<T: RemoteConfigSerializable>(key: RemoteConfigKey<T>) -> T.T where T.T == T {
        get {
            if let value = T._remoteConfig.get(key: key._key, remoteConfig: self) {
                return value
            } else if let defaultValue = key.defaultValue {
                return defaultValue
            } else {
                fatalError("Unexpected path is executed. please report to https://github.com/fumito-ito/RemoteConfigSwift")
            }
        }
    }
}
