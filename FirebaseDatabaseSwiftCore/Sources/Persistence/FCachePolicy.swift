//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 05/03/2022.
//

import Foundation

private let kFServerUpdatesBetweenCacheSizeChecks = 1000
private let kFMaxNumberOfPrunableQueriesToKeep = 1000
private let kFPercentOfQueriesToPruneAtOnce = 0.2

@objc public protocol FCachePolicy: NSObjectProtocol {
    func shouldPruneCache(size cacheSize: Int, numberOfTrackedQueries numTrackedQueries: Int) -> Bool
    func shouldCheckCacheSize(_ serverUpdatesSinceLastCheck: Int) -> Bool
    var percentOfQueriesToPruneAtOnce: Double { get }
    var maxNumberOfQueriesToKeep: Int { get }
}

@objc public class FLRUCachePolicy: NSObject, FCachePolicy {
    @objc public let maxSize: Int
    @objc public init(maxSize: Int) {
        self.maxSize = maxSize
    }
    public func shouldPruneCache(size cacheSize: Int, numberOfTrackedQueries numTrackedQueries: Int) -> Bool {
        cacheSize > maxSize ||
        numTrackedQueries > kFMaxNumberOfPrunableQueriesToKeep
    }

    public func shouldCheckCacheSize(_ serverUpdatesSinceLastCheck: Int) -> Bool {
        serverUpdatesSinceLastCheck > kFServerUpdatesBetweenCacheSizeChecks
    }

    public var percentOfQueriesToPruneAtOnce: Double { kFPercentOfQueriesToPruneAtOnce }
    public var maxNumberOfQueriesToKeep: Int { kFMaxNumberOfPrunableQueriesToKeep }
}

@objc public class FNoCachePolicy: NSObject, FCachePolicy {
    @objc public static var noCachePolicy: FNoCachePolicy = FNoCachePolicy()
    public func shouldCheckCacheSize(_ serverUpdatesSinceLastCheck: Int) -> Bool {
        false
    }

    public func shouldPruneCache(size cacheSize: Int, numberOfTrackedQueries numTrackedQueries: Int) -> Bool {
        false
    }

    public var maxNumberOfQueriesToKeep: Int {
        Int.max
    }

    public var percentOfQueriesToPruneAtOnce: Double { 0 }
}
