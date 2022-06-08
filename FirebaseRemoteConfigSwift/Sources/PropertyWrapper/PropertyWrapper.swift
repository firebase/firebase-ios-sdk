//
//  PropertyWrapper.swift
//  
//
//  Created by Fumito Ito on 2022/05/25.
//

import SwiftUI
import FirebaseRemoteConfig

@available(iOS 14.0, macOS 11.0, macCatalyst 14.0, tvOS 14.0, watchOS 7.0, *)
@propertyWrapper
public struct RemoteConfigProperty<T: Decodable>: DynamicProperty {
    @State private var configValueObserver: RemoteConfigValueObservable<T>

    public let key: String
    public let remoteConfig: RemoteConfig
    public var lastFetchStatus: RemoteConfigFetchStatus {
        return remoteConfig.lastFetchStatus
    }
    public var lastFetchTime: Date? {
        return remoteConfig.lastFetchTime
    }

    public var wrappedValue: T {
        get {
            configValueObserver.configValue
        }
    }

    public init(
        forKey key: String
    ) {
        self.key = key
        self.remoteConfig = RemoteConfig.remoteConfig()

        _configValueObserver = State(
            wrappedValue: RemoteConfigValueObservable<T>(
                key: key,
                remoteConfig: RemoteConfig.remoteConfig()
            )
        )
    }

    public init(
        forKey key: String,
        remoteConfig: RemoteConfig
    ) {
        self.key = key
        self.remoteConfig = remoteConfig

        _configValueObserver = State(
            wrappedValue: RemoteConfigValueObservable<T>(
                key: key,
                remoteConfig: remoteConfig
            )
        )
    }
}
