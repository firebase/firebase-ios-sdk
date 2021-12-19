//
//  RemoteConfigKey.swift
//  RemoteConfigSwift
//
//  Created by 伊藤史 on 2020/08/15.
//  Copyright © 2020 Fumito Ito. All rights reserved.
//

import Foundation

public struct RemoteConfigKey<ValueType: RemoteConfigSerializable> {

    public let _key: String
    public let defaultValue: ValueType.T?
    internal var isOptional: Bool

    public init(_ key: String, defaultValue: ValueType.T) {
        self._key = key
        self.defaultValue = defaultValue
        self.isOptional = false
    }

    private init(key: String) {
        self._key = key
        self.defaultValue = nil
        self.isOptional = true
    }

    @available(*, unavailable, message: "This key needs a `defaultValue` parameter. If this type does not have a default value, consider using an optional key.")
    public init(_ key: String) {
        fatalError()
    }
}

public extension RemoteConfigKey where ValueType: RemoteConfigSerializable, ValueType: OptionalType, ValueType.Wrapped: RemoteConfigSerializable {

    init(_ key: String) {
        self.init(key: key)
    }

    init(_ key: String, defaultValue: ValueType.T) {
        self._key = key
        self.defaultValue = defaultValue
        self.isOptional = true
    }
}
