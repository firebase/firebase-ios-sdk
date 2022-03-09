//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 09/03/2022.
//

import Foundation

@objc public class FAckUserWrite: NSObject, FOperation {
    @objc public let source: FOperationSource
    @objc public let type: FOperationType
    @objc public let path: FPath
    // A FImmutableTree, containing @YES for each affected path.  Affected paths
    // can't overlap.
    @objc public let affectedTree: FImmutableTree
    @objc public let revert: Bool
    @objc public init(path operationPath: FPath,
                      affectedTree: FImmutableTree,
                      revert shouldRevert: Bool) {
        self.source = .userInstance
        self.type = .ackUserWrite
        self.path = operationPath
        self.affectedTree = affectedTree
        self.revert = shouldRevert
    }

    public func operationForChild(_ childKey: String) -> FOperation? {
        if !path.isEmpty() {
            assert(path.getFront() == childKey, "operationForChild called for unrelated child.")
            return FAckUserWrite(path: path.popFront(),
                                 affectedTree: affectedTree,
                                 revert: revert)
        } else if affectedTree.value != nil {
            assert(affectedTree.childrenIsEmpty(), "affectedTree should not have overlapping affected paths.")
            // All child locations are affected as well; just return same operation.
            return self
        } else {
            let childTree = affectedTree.subtree(atPath: FPath(with: childKey))
            return FAckUserWrite(path: FPath.empty(),
                                 affectedTree: childTree,
                                 revert: revert)
        }
    }

    public override var description: String {
        "FAckUserWrite { path=\(path), revert=\(revert), affectedTree=\(affectedTree) }"
    }
}
