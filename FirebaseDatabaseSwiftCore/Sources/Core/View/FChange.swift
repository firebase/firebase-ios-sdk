//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 27/02/2022.
//

import Foundation

@objc public class FChange: NSObject {
    @objc public let type: DataEventType
    @objc public let indexedNode: FIndexedNode
    @objc public let childKey: String?
    @objc public let prevKey: String?
    @objc public let oldIndexedNode: FIndexedNode?

    @objc public init(type: DataEventType, indexedNode: FIndexedNode) {
        self.type = type
        self.indexedNode = indexedNode
        self.childKey = nil
        self.oldIndexedNode = nil
        self.prevKey = nil
    }

    @objc public init(type: DataEventType, indexedNode: FIndexedNode, childKey: String?) {
        self.type = type
        self.indexedNode = indexedNode
        self.childKey = childKey
        self.oldIndexedNode = nil
        self.prevKey = nil
    }

    @objc public init(type: DataEventType, indexedNode: FIndexedNode, childKey: String?, oldIndexedNode: FIndexedNode?) {
        self.type = type
        self.indexedNode = indexedNode
        self.childKey = childKey
        self.oldIndexedNode = oldIndexedNode
        self.prevKey = nil
    }

    private init(type: DataEventType, indexedNode: FIndexedNode, childKey: String?, oldIndexedNode: FIndexedNode?, prevKey: String?) {
        self.type = type
        self.indexedNode = indexedNode
        self.childKey = childKey
        self.oldIndexedNode = oldIndexedNode
        self.prevKey = prevKey
    }

    @objc public func change(prevKey: String?) -> FChange {
        FChange(type: type,
                indexedNode: indexedNode,
                childKey: childKey,
                oldIndexedNode: oldIndexedNode,
                prevKey: prevKey)
    }

    @objc public override var description: String {
        "event: \(type.rawValue), data: \(indexedNode.node.val())"
    }
    
    public override var debugDescription: String {
        "event: \(type.rawValue), data: \(indexedNode.node.val())"
    }
}

/*


 */
