//
//  File.swift
//
//
//  Created by Themis Wang on 2023-11-16.
//

import Foundation

@objc(FIRRolloutsStateSubscriber)
public protocol RolloutsStateSubscriber {
  func onRolloutsStateChanged(_ rolloutsState: RolloutsState)
}
