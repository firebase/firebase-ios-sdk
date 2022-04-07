//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 07/04/2022.
//

import Foundation

@objc public class FSparseSnapshotTree: NSObject {
    var value: FNode?
    var children: [String: FSparseSnapshotTree] = [:]

    @objc public func findPath(_ path: FPath) -> FNode? {
        if let value = value {
            return value.getChild(path)
        } else if let childKey = path.getFront(), !children.isEmpty {
            if let childTree = children[childKey] {
                return childTree.findPath(path.popFront())
            } else {
                return nil
            }
        } else {
            return nil
        }
    }

    @objc public func rememberData(_ data: FNode, onPath path: FPath) {
        if path.isEmpty {
            value = data
            children = [:]
        } else if let value = value {
            self.value = value.updateChild(path, withNewChild: data)
        } else {
            guard let childKey = path.getFront() else {
                return
            }
            let child = children[childKey, default: FSparseSnapshotTree()]
            child.rememberData(data, onPath: path.popFront())
            children[childKey] = child
        }
    }

    @objc public func forgetPath(_ path: FPath) -> Bool {
        if path.isEmpty {
            value = nil
            children = [:]
            return true
        } else if let value = value {
            if value.isLeafNode() {
                // non-empty path at leaf. the path leads to nowhere
                return false
            } else {
                let tmp = value
                self.value = nil
                tmp.enumerateChildren { key, node, stop in
                    self.rememberData(node, onPath: FPath(with: key))
                }
                // we've cleared out the value and set children. Call ourself
                // again to hit the next case
                return self.forgetPath(path)
            }
        } else if !children.isEmpty {
            let childKey = path.getFront()! // XXX TODO: FORCE UNWRAP IS SAFE HERE, BUT NOT NICE TO LOOK AT
            let p = path.popFront()
            if let child = children[childKey] {
                let safeToRemove = child.forgetPath(p)
                if safeToRemove {
                    children.removeValue(forKey: childKey)
                }
            }
            if children.isEmpty {
                return true
            } else {
                return false
            }
        } else {
            return true
        }
    }

    @objc public func forEachTreeAtPath(_ prefixPath: FPath, do closure: (FPath, FNode) -> Void) {
        if let value = value {
            closure(prefixPath, value)
        } else {
            forEachChild { key, tree in
                let path = prefixPath.child(fromString: key)
                tree.forEachTreeAtPath(path, do: closure)
            }
        }
    }

    @objc public func forEachChild(_ closure: (String, FSparseSnapshotTree) -> Void) {
        for (key, tree) in children {
            closure(key, tree)
        }
    }
}
