//
//  RemoteConfigBridge.swift
//  SwiftyRemoteConfig
//
//  Created by 伊藤史 on 2020/08/13.
//  Copyright © 2020 Fumito Ito. All rights reserved.
//

import Foundation
import FirebaseRemoteConfig

public protocol RemoteConfigBridge {
    associatedtype T

    func get(key: String, remoteConfig: RemoteConfig) -> T?
    func deserialize(_ object: RemoteConfigValue) -> T?
}

public struct RemoteConfigObjectBridge<T>: RemoteConfigBridge {
    public init() {}

    public func get(key: String, remoteConfig: RemoteConfig) -> T? {
        return remoteConfig.configValue(forKey: key) as? T
    }

    public func deserialize(_ object: RemoteConfigValue) -> T? {
        return nil
    }
}

public struct RemoteConfigArrayBridge<T: Collection>: RemoteConfigBridge {
    public init() {}

    public func get(key: String, remoteConfig: RemoteConfig) -> T? {
        return remoteConfig.configValue(forKey: key) as? T
    }

    public func deserialize(_ object: RemoteConfigValue) -> T? {
        return nil
    }
}

public struct RemoteConfigStringBridge: RemoteConfigBridge {
    public init() {}

    public func get(key: String, remoteConfig: RemoteConfig) -> String? {
        let configValue = remoteConfig.configValue(forKey: key)
        
        if configValue.stringValue?.isEmpty == true || configValue.stringValue.isNil {
            return nil
        }
        
        return configValue.stringValue
    }

    public func deserialize(_ object: RemoteConfigValue) -> String? {
        return nil
    }
}

public struct RemoteConfigIntBridge: RemoteConfigBridge {
    public init() {}

    public func get(key: String, remoteConfig: RemoteConfig) -> Int? {
        let configValue = remoteConfig.configValue(forKey: key)
        
        if configValue.stringValue?.isEmpty == true || configValue.stringValue.isNil {
            return nil
        }
        
        return configValue.numberValue.intValue
    }

    public func deserialize(_ object: RemoteConfigValue) -> Int? {
        return nil
    }
}

public struct RemoteConfigDoubleBridge: RemoteConfigBridge {
    public init() {}

    public func get(key: String, remoteConfig: RemoteConfig) -> Double? {
        let configValue = remoteConfig.configValue(forKey: key)
        
        if configValue.stringValue?.isEmpty == true || configValue.stringValue.isNil {
            return nil
        }
        
        return configValue.numberValue.doubleValue
    }

    public func deserialize(_ object: RemoteConfigValue) -> Double? {
        return nil
    }
}

public struct RemoteConfigBoolBridge: RemoteConfigBridge {
    public init() {}

    public func get(key: String, remoteConfig: RemoteConfig) -> Bool? {
        let configValue = remoteConfig.configValue(forKey: key)
        
        if configValue.stringValue?.isEmpty == true || configValue.stringValue.isNil {
            return nil
        }
        
        return remoteConfig.configValue(forKey: key).boolValue
    }

    public func deserialize(_ object: RemoteConfigValue) -> Bool? {
        return nil
    }
}

public struct RemoteConfigDataBridge: RemoteConfigBridge {
    public init() {}

    public func get(key: String, remoteConfig: RemoteConfig) -> Data? {
        let dataValue = remoteConfig.configValue(forKey: key).dataValue
        return dataValue.isEmpty ? nil : dataValue
    }

    public func deserialize(_ object: RemoteConfigValue) -> Data? {
        return nil
    }
}

public struct RemoteConfigUrlBridge: RemoteConfigBridge {
    public init() {}

    public func get(key: String, remoteConfig: RemoteConfig) -> URL? {
        return self.deserialize(remoteConfig.configValue(forKey: key))
    }

    public func deserialize(_ object: RemoteConfigValue) -> URL? {
        if let url = NSKeyedUnarchiver.unarchiveObject(with: object.dataValue) as? URL {
            return url
        }

        if let stringValue = object.stringValue, stringValue.isEmpty == false {
            if let url = URL(string: stringValue) {
                return url
            }

            let path = (stringValue as NSString).expandingTildeInPath
            return URL(fileURLWithPath: path)
        }

        return nil
    }
}

public struct RemoteConfigCodableBridge<T: Codable>: RemoteConfigBridge {
    public func get(key: String, remoteConfig: RemoteConfig) -> T? {
        return self.deserialize(remoteConfig.configValue(forKey: key))
    }

    public func deserialize(_ object: RemoteConfigValue) -> T? {
        return try? JSONDecoder().decode(T.self, from: object.dataValue)
    }
}

public struct RemoteConfigKeyedArchiverBridge<T>: RemoteConfigBridge {
    public func get(key: String, remoteConfig: RemoteConfig) -> T? {
        return self.deserialize(remoteConfig.configValue(forKey: key))
    }

    public func deserialize(_ object: RemoteConfigValue) -> T? {
        return NSKeyedUnarchiver.unarchiveObject(with: object.dataValue) as? T
    }
}

public struct RemoteConfigRawRepresentableBridge<T: RawRepresentable>: RemoteConfigBridge {
    public func get(key: String, remoteConfig: RemoteConfig) -> T? {
        return self.deserialize(remoteConfig.configValue(forKey: key))
    }

    public func deserialize(_ object: RemoteConfigValue) -> T? {
        if let rawValue = object.stringValue as? T.RawValue {
            return T(rawValue: rawValue)
        }

        if let rawValue = object.numberValue as? T.RawValue {
            return T(rawValue: rawValue)
        }

        return nil
    }
}

public struct RemoteConfigRawRepresentableArrayBridge<T: Collection>: RemoteConfigBridge where T.Element: RawRepresentable {
    public func get(key: String, remoteConfig: RemoteConfig) -> T? {
        return self.deserialize(remoteConfig.configValue(forKey: key))
    }

    public func deserialize(_ object: RemoteConfigValue) -> T? {
        guard let rawValues = object.jsonValue as? [T.Element.RawValue] else {
            return nil
        }

        return rawValues.compactMap({ T.Element(rawValue: $0) }) as? T
    }
}

public struct RemoteConfigOptionalBridge<Bridge: RemoteConfigBridge>: RemoteConfigBridge {
    public typealias T = Bridge.T?

    private let bridge: Bridge

    public init(bridge: Bridge) {
        self.bridge = bridge
    }

    public func get(key: String, remoteConfig: RemoteConfig) -> T? {
        return self.bridge.get(key: key, remoteConfig: remoteConfig)
    }

    public func deserialize(_ object: RemoteConfigValue) -> T? {
        return self.bridge.deserialize(object)
    }
}

public struct RemoteConfigOptionalArrayBridge<Bridge: RemoteConfigBridge>: RemoteConfigBridge where Bridge.T: Collection {
    public typealias T = Bridge.T

    private let bridge: Bridge

    public init(bridge: Bridge) {
        self.bridge = bridge
    }

    public func get(key: String, remoteConfig: RemoteConfig) -> T? {
        return self.bridge.get(key: key, remoteConfig: remoteConfig)
    }

    public func deserialize(_ object: RemoteConfigValue) -> T? {
        return self.bridge.deserialize(object)
    }
}
