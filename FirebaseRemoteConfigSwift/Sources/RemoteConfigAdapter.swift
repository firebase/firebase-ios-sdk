//
//  RemoteConfigAdapter.swift
//  RemoteConfigSwift
//
//  Created by 伊藤史 on 2020/08/15.
//  Copyright © 2020 Fumito Ito. All rights reserved.
//

import Foundation
import FirebaseRemoteConfig

@dynamicMemberLookup
public struct RemoteConfigAdapter<KeyStore: RemoteConfigKeyStore> {

    public let remoteConfig: RemoteConfig
    public let keyStore: KeyStore

    public init(remoteConfig: RemoteConfig, keyStore: KeyStore) {
        self.remoteConfig = remoteConfig
        self.keyStore = keyStore
    }

    @available(*, unavailable)
    public subscript(dynamicMember member: String) -> Never {
        fatalError()
    }

    public func hasKey<T: RemoteConfigSerializable>(_ key: RemoteConfigKey<T>) -> Bool {
        return self.remoteConfig.hasKey(key)
    }

    public func hasKey<T: RemoteConfigSerializable>(_ keyPath: KeyPath<KeyStore, RemoteConfigKey<T>>) -> Bool {
        return self.remoteConfig.hasKey(self.keyStore[keyPath: keyPath])
    }
}
