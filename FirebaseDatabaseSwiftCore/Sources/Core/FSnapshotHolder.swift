//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 09/03/2022.
//

import Foundation

@objc public class FSnapshotHolder: NSObject {
    @objc public var rootNode = FEmptyNode.emptyNode

    @objc public override init() {}

    @objc public func getNode(_ path: FPath) -> FNode {
        rootNode.getChild(path)
    }

    @objc public func updateSnapshot(_ path: FPath, withNewSnapshot newSnapshotNode: FNode) {
        self.rootNode = self.rootNode.updateChild(path, withNewChild: newSnapshotNode)
    }
}
