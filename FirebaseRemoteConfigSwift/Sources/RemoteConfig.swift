//
//  RemoteConfig.swift
//  RemoteConfigSwift
//
//  Created by 伊藤史 on 2020/08/13.
//  Copyright © 2020 Fumito Ito. All rights reserved.
//

import Foundation
import FirebaseRemoteConfig

public var RemoteConfigs = RemoteConfigAdapter<RemoteConfigKeys>(remoteConfig: RemoteConfig.remoteConfig(), keyStore: .init())

public extension RemoteConfig {
    func hasKey<T: RemoteConfigSerializable>(_ key: RemoteConfigKey<T>) -> Bool {
        self.configValue(forKey: key._key).stringValue != nil
    }
}
