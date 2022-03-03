//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 27/02/2022.
//

import Foundation

@objc public class FChildChangeAccumulator: NSObject {
    private var changeMap: [String: FChange] = [:]
    @objc public var changes: [FChange] { Array(changeMap.values) }
    @objc public override init() {}
    @objc public func trackChildChange(_ change: FChange) {
        let type = change.type
        guard let childKey = change.childKey else { return }
        assert(type == .childAdded || type == .childChanged || type == .childRemoved, "Only child changes supported for tracking.")
        assert(childKey != ".priority", "Changes not tracked on priority")
        guard let oldChange = changeMap[childKey] else {
            changeMap[childKey] = change
            return
        }
        let oldType = oldChange.type
        switch (type, oldType) {
        case (.childAdded, .childRemoved):
            let newChange = FChange(type: .childChanged,
                                    indexedNode: change.indexedNode,
                                    childKey: childKey,
                                    oldIndexedNode: oldChange.indexedNode)
            changeMap[childKey] = newChange
        case (.childRemoved, .childAdded):
            changeMap.removeValue(forKey: childKey)

        case (.childRemoved, .childChanged):
            let newChange = FChange(type: .childRemoved,
                                    indexedNode: oldChange.oldIndexedNode!,
                                    childKey: childKey)
            changeMap[childKey] = newChange

        case (.childChanged, .childAdded):
            let newChange = FChange(type: .childAdded,
                                    indexedNode: change.indexedNode,
                                    childKey: childKey)
            changeMap[childKey] = newChange

        case (.childChanged, .childChanged):
            let newChange = FChange(type: .childChanged,
                                    indexedNode: change.indexedNode,
                                    childKey: childKey,
                                    oldIndexedNode: oldChange.oldIndexedNode!)
            changeMap[childKey] = newChange

        case (_, _):
            fatalError("Illegal combination of changes: \(change) occurred after \(oldChange)")
        }
    }
}

