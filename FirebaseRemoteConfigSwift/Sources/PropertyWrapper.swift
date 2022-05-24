//
//  PropertyWrapper.swift
//  
//
//  Created by Fumito Ito on 2022/05/25.
//

import FirebaseRemoteConfig

@available(iOS 14.0, macOS 11.0, macCatalyst 14.0, tvOS 14.0, watchOS 7.0, *)
@propertyWrapper
public struct RemoteConfigProperty<T: Decodable> {
    private let key: String
    private let remoteConfig: RemoteConfig

    public var wrappedValue: T? {
        get {
            try? self.remoteConfig[self.key].decoded(asType: T.self)
        }
        @available(*, unavailable, message: "RemoteConfig property wrapper does not support setting property.")
        set {
            fatalError("RemoteConfig property wrapper does not support setting property.")
        }
    }

    public init(
        forKey key: String
    ) {
        self.key = key
        self.remoteConfig = RemoteConfig.remoteConfig()
    }

    public init(
        forKey key: String,
        remoteConfig: RemoteConfig
    ) {
        self.key = key
        self.remoteConfig = remoteConfig
    }
}
