//
//  TestHelper.swift
//  
//
//  Created by 伊藤史 on 2021/11/16.
//

import Foundation
import SwiftyRemoteConfig
import Firebase
import XCTest

func given(_ description: String, closure: @escaping (XCTActivity) -> Void) {
    XCTContext.runActivity(named: description, block: closure)
}

func when(_ description: String, closure: @escaping (XCTActivity) -> Void) {
    XCTContext.runActivity(named: description, block: closure)
}

func then(_ description: String, closure: @escaping (XCTActivity) -> Void) {
    XCTContext.runActivity(named: description, block: closure)
}

final class FrogSerializable: NSObject, RemoteConfigSerializable, NSCoding {
    typealias T = FrogSerializable
    
    let name: String
    
    init(name: String = "Froggy") {
        self.name = name
    }
    
    init?(coder: NSCoder) {
        guard let name = coder.decodeObject(forKey: "name") as? String else {
            return nil
        }
        
        self.name = name
    }
    
    func encode(with coder: NSCoder) {
        coder.encode(name, forKey: "name")
    }
    
    override func isEqual(_ object: Any?) -> Bool {
        guard let object = object as? FrogSerializable else {
            return false
        }
        
        return name == object.name
    }
}

struct FrogCodable: Codable, Equatable, RemoteConfigSerializable {
    let name: String
    
    init(name: String = "Froggy") {
        self.name = name
    }
}

enum BestFroggiesEnum: String, RemoteConfigSerializable {
    case Andy
    case Dandy
}

struct FrogCustomSerializable: RemoteConfigSerializable, Equatable {
    static var _remoteConfig: RemoteConfigFrogBridge { return RemoteConfigFrogBridge() }
    static var _remoteConfigArray: RemoteConfigFrogArrayBridge { return RemoteConfigFrogArrayBridge() }
    
    typealias Bridge = RemoteConfigFrogBridge
    
    typealias ArrayBridge = RemoteConfigFrogArrayBridge
    
    
    let name: String
}

final class RemoteConfigFrogBridge: RemoteConfigBridge {
    func get(key: String, remoteConfig: RemoteConfig) -> FrogCustomSerializable? {
        guard let name = remoteConfig.configValue(forKey: key).stringValue, name.isEmpty == false else {
            return nil
        }
        
        return FrogCustomSerializable.init(name: name)
    }
    
    func deserialize(_ object: RemoteConfigValue) -> FrogCustomSerializable? {
        guard let name = object.stringValue, name.isEmpty == false else {
            return nil
        }

        return FrogCustomSerializable.init(name: name)
    }
}

final class RemoteConfigFrogArrayBridge: RemoteConfigBridge {
    func get(key: String, remoteConfig: RemoteConfig) -> [FrogCustomSerializable]? {
        return remoteConfig.configValue(forKey: key)
            .jsonValue
            .map({ $0 as? [String] })
            .flatMap({ $0 })?
            .map(FrogCustomSerializable.init)
    }
    
    func deserialize(_ object: RemoteConfigValue) -> Array<FrogCustomSerializable>? {
        // In remote config, array is configured as JSON value
        guard let names = object.jsonValue as? [String] else {
            return nil
        }
        
        return names.map(FrogCustomSerializable.init)
    }
}

final class FrogKeyStore<Serializable: RemoteConfigSerializable & Equatable>: RemoteConfigKeyStore {
    lazy var testValue: RemoteConfigKey<Serializable> = { fatalError("not initialized yet") }()
    lazy var testArray: RemoteConfigKey<[Serializable]> = { fatalError("not initialized yet") }()
    lazy var testOptionalValue: RemoteConfigKey<Serializable?> = { fatalError("not initialized yet") }()
    lazy var testOptionalArray: RemoteConfigKey<[Serializable]?> = { fatalError("not initialized yet") }()
}
