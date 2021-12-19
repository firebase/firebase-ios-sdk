//
//  RemoteConfigSerializable.swift
//  RemoteConfigSwift
//
//  Created by 伊藤史 on 2020/08/15.
//  Copyright © 2020 Fumito Ito. All rights reserved.
//

import Foundation

public protocol RemoteConfigSerializable {
    typealias T = Bridge.T
    associatedtype Bridge: RemoteConfigBridge
    associatedtype ArrayBridge: RemoteConfigBridge

    static var _remoteConfig: Bridge { get }
    static var _remoteConfigArray: ArrayBridge { get }
}
