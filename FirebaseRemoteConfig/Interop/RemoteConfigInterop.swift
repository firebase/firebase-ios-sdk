//
//  File.swift
//
//
//  Created by Themis Wang on 2023-11-16.
//

import Foundation

@objc(FIRRemoteConfigInterop)
public protocol RemoteConfigInterop {
  func registerRolloutsStateSubscriber(_ namespace: String,
                                       subscriber: RolloutsStateSubscriber?)
}
