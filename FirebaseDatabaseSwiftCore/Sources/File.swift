//
//  File.swift
//  File
//
//  Created by Morten Bek Ditlevsen on 04/09/2021.
//

import Foundation
@objc public class MBDTest: NSObject {
    public var a: Int = 1
    @objc public init(a: Int) {
        self.a = a
    }
}


@objc public protocol FClock: NSObjectProtocol {
    @objc var currentTime: TimeInterval { get }
}

@objc public class FSystemClock: NSObject, FClock {
    @objc public static var clock: FSystemClock = FSystemClock()
    @objc public var currentTime: TimeInterval {
        Date().timeIntervalSince1970
    }
}

@objc public class FOffsetClock: NSObject, FClock {
    private let clock: FClock
    private let offset: TimeInterval
    @objc public init(clock: FClock, offset: TimeInterval) {
        self.clock = clock
        self.offset = offset
    }
    @objc public var currentTime: TimeInterval {
        clock.currentTime + offset
    }
}
