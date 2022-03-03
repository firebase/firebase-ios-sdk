//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 03/03/2022.
//

import Foundation

@objc public class FTrackedQuery: NSObject {
    @objc public let queryId: Int
    @objc public let query: FQuerySpec
    @objc public let lastUse: TimeInterval
    @objc public let isComplete: Bool
    @objc public let isActive: Bool

    @objc public init(id queryId: Int, query: FQuerySpec, lastUse: TimeInterval, isActive: Bool, isComplete: Bool) {
        self.queryId = queryId
        self.query = query
        self.lastUse = lastUse
        self.isActive = isActive
        self.isComplete = isComplete
    }

    @objc public init(id queryId: Int, query: FQuerySpec, lastUse: TimeInterval, isActive: Bool) {
        self.queryId = queryId
        self.query = query
        self.lastUse = lastUse
        self.isActive = isActive
        self.isComplete = false
    }

    @objc public func updateLastUse(_ lastUse: TimeInterval) -> FTrackedQuery {
        .init(id: queryId, query: query, lastUse: lastUse, isActive: isActive, isComplete: isComplete)
    }

    @objc public func setComplete() -> FTrackedQuery {
        .init(id: queryId, query: query, lastUse: lastUse, isActive: isActive, isComplete: true)
    }

    @objc public func setActiveState(_ isActive: Bool) -> FTrackedQuery {
        .init(id: queryId, query: query, lastUse: lastUse, isActive: isActive, isComplete: true)
    }

    public override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? FTrackedQuery else { return false }
        return queryId == other.queryId &&
        query == other.query &&
        lastUse == other.lastUse &&
        isComplete == other.isComplete &&
        isActive == other.isActive
    }

    public override var hash: Int {
        var hasher = Hasher()
        queryId.hash(into: &hasher)
        query.hash(into: &hasher)
        isActive.hash(into: &hasher)
        isComplete.hash(into: &hasher)
        lastUse.hash(into: &hasher)
        return hasher.finalize()
    }
}
