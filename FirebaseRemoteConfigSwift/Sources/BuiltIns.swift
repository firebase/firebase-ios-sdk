//
//  BuiltIns.swift
//  RemoteConfigSwiftExample
//
//  Created by 伊藤史 on 2020/08/25.
//  Copyright © 2020 Fumito Ito. All rights reserved.
//

import Foundation

extension RemoteConfigSerializable {
    public static var _remoteConfigArray: RemoteConfigArrayBridge<[T]> { RemoteConfigArrayBridge() }
}

extension Date: RemoteConfigSerializable {
    public static var _remoteConfig: RemoteConfigObjectBridge<Date> { RemoteConfigObjectBridge() }
}

extension String: RemoteConfigSerializable {
    public static var _remoteConfig: RemoteConfigStringBridge { RemoteConfigStringBridge() }
}

extension Int: RemoteConfigSerializable {
    public static var _remoteConfig: RemoteConfigIntBridge { RemoteConfigIntBridge() }
}

extension Double: RemoteConfigSerializable {
    public static var _remoteConfig: RemoteConfigDoubleBridge { return RemoteConfigDoubleBridge() }
}

extension Bool: RemoteConfigSerializable {
    public static var _remoteConfig: RemoteConfigBoolBridge { RemoteConfigBoolBridge() }
}

extension Data: RemoteConfigSerializable {
    public static var _remoteConfig: RemoteConfigDataBridge { RemoteConfigDataBridge() }
}

extension URL: RemoteConfigSerializable {
    public static var _remoteConfig: RemoteConfigUrlBridge { RemoteConfigUrlBridge() }
    public static var _remoteConfigArray: RemoteConfigCodableBridge<[URL]> { RemoteConfigCodableBridge() }
}

extension RemoteConfigSerializable where Self: Codable {
    public static var _remoteConfig: RemoteConfigCodableBridge<Self> { RemoteConfigCodableBridge() }
    public static var _remoteConfigArray: RemoteConfigCodableBridge<[Self]> { RemoteConfigCodableBridge() }
}

extension RemoteConfigSerializable where Self: RawRepresentable {
    public static var _remoteConfig: RemoteConfigRawRepresentableBridge<Self> { RemoteConfigRawRepresentableBridge() }
    public static var _remoteConfigArray: RemoteConfigRawRepresentableArrayBridge<[Self]> { RemoteConfigRawRepresentableArrayBridge() }
}

extension RemoteConfigSerializable where Self: NSCoding {
    public static var _remoteConfig: RemoteConfigKeyedArchiverBridge<Self> { RemoteConfigKeyedArchiverBridge() }
    public static var _remoteConfigArray: RemoteConfigKeyedArchiverBridge<[Self]> { RemoteConfigKeyedArchiverBridge() }
}

extension Dictionary: RemoteConfigSerializable where Key == String {
    public typealias T = [Key: Value]
    public typealias Bridge = RemoteConfigObjectBridge<T>
    public typealias ArrayBridge = RemoteConfigArrayBridge<[T]>

    public static var _remoteConfig: Bridge { Bridge() }
    public static var _remoteConfigArray: ArrayBridge { ArrayBridge() }
}

extension Array: RemoteConfigSerializable where Element: RemoteConfigSerializable {
    public typealias T = [Element.T]
    public typealias Bridge = Element.ArrayBridge
    public typealias ArrayBridge = RemoteConfigObjectBridge<[T]>

    public static var _remoteConfig: Bridge { Element._remoteConfigArray }
    public static var _remoteConfigArray: ArrayBridge {
        fatalError("Multidimensional arrays are not supported yet")
    }
}

extension Optional: RemoteConfigSerializable where Wrapped: RemoteConfigSerializable {
    public typealias Bridge = RemoteConfigOptionalBridge<Wrapped.Bridge>
    public typealias ArrayBridge = RemoteConfigOptionalBridge<Wrapped.ArrayBridge>

    public static var _remoteConfig: Bridge { RemoteConfigOptionalBridge(bridge: Wrapped._remoteConfig) }
    public static var _remoteConfigArray: ArrayBridge { RemoteConfigOptionalBridge(bridge: Wrapped._remoteConfigArray) }
}
