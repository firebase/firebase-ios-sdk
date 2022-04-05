//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 09/03/2022.
//

import Foundation

class FAckUserWrite: NSObject, FOperation {
    let source: FOperationSource
    let type: FOperationType
    let path: FPath
    // A FImmutableTree<Bool>, containing true for each affected path.  Affected paths
    // can't overlap.
    let affectedTree: FImmutableTree<Bool>
    let revert: Bool
    init(path operationPath: FPath,
         affectedTree: FImmutableTree<Bool>,
         revert shouldRevert: Bool) {
        self.source = .userInstance
        self.type = .ackUserWrite
        self.path = operationPath
        self.affectedTree = affectedTree
        self.revert = shouldRevert
    }

    public func operationForChild(_ childKey: String) -> FOperation? {
        if !path.isEmpty {
            assert(path.getFront() == childKey, "operationForChild called for unrelated child.")
            return FAckUserWrite(path: path.popFront(),
                                 affectedTree: affectedTree,
                                 revert: revert)
        } else if affectedTree.value != nil {
            assert(affectedTree.childrenIsEmpty, "affectedTree should not have overlapping affected paths.")
            // All child locations are affected as well; just return same operation.
            return self
        } else {
            let childTree = affectedTree.subtree(atPath: FPath(with: childKey))
            return FAckUserWrite(path: .empty,
                                 affectedTree: childTree,
                                 revert: revert)
        }
    }

    public override var description: String {
        "FAckUserWrite { path=\(path), revert=\(revert), affectedTree=\(affectedTree) }"
    }
}
