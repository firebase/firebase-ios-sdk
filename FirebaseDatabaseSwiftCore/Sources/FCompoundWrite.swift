//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 28/09/2021.
//

import Foundation
/**
 * This class holds a collection of writes that can be applied to nodes in
 * unison. It abstracts away the logic with dealing with priority writes and
 * multiple nested writes. At any given path, there is only allowed to be one
 * write modifying that path. Any write to an existing path or shadowing an
 * existing path will modify that existing write to reflect the write added.
 */
@objc public class FCompoundWrite: NSObject {
    let writeTree: FImmutableTreeSwift<FNode>
    init(writeTree: FImmutableTreeSwift<FNode>) {
        self.writeTree = writeTree
    }

    /**
     * Creates a compound write with NSDictionary from path string to object
     */
    @objc public static func compoundWrite(valueDictionary dictionary: NSDictionary) -> FCompoundWrite {
        var writeTree: FImmutableTreeSwift<FNode> = .empty()
        dictionary.enumerateKeysAndObjects { pathString, value, _ in
            guard let path = pathString as? String else { return }
            let node = FSnapshotUtilitiesSwift.nodeFrom(value)
            let tree = FImmutableTreeSwift<FNode>(value: node)
            writeTree = writeTree.setTree(tree, atPath: FPath(with: path))
        }
        return FCompoundWrite(writeTree: writeTree)
    }

    @objc public static func compoundWrite(nodeDictionary dictionary: NSDictionary) -> FCompoundWrite {
        var writeTree = FImmutableTreeSwift<FNode>.empty()
        dictionary.enumerateKeysAndObjects { key, value, _ in
            guard let pathString = key as? String else { return }
            guard let node = value as? FNode else { return }
            let tree = FImmutableTreeSwift(value: node)
            writeTree = writeTree.setTree(tree, atPath: FPath(with: pathString))
        }
        return FCompoundWrite(writeTree: writeTree)
    }

    @objc public static let emptyWrite: FCompoundWrite = FCompoundWrite(writeTree: .empty())

    @objc public func addWrite(_ node: FNode, atPath path: FPath) -> FCompoundWrite {
        if path.isEmpty() {
            return FCompoundWrite(writeTree: FImmutableTreeSwift(value: node))
        } else {
            if let rootMost = writeTree.findRootMostValueAndPath(path) {
                let relativePath = FPath.relativePath(from: rootMost.path, to: path)
                let value = rootMost.value.updateChild(relativePath, withNewChild: node)
                return FCompoundWrite(writeTree: self.writeTree.setValue(value, atPath: rootMost.path))
            } else {
                let subtree = FImmutableTreeSwift<FNode>(value: node)
                let newWriteTree = self.writeTree.setTree(subtree, atPath: path)
                return FCompoundWrite(writeTree: newWriteTree)
            }
        }
    }

    @objc public func addWrite(_ node: FNode, atKey key: String) -> FCompoundWrite {
        addWrite(node, atPath: FPath(with: key))
    }

    @objc public func addCompoundWrite(_ compoundWrite: FCompoundWrite, atPath path: FPath) -> FCompoundWrite {
        var newWrite = self
        compoundWrite.writeTree.forEach { childPath, value in
            newWrite = newWrite.addWrite(value, atPath: path.child(childPath))
        }
        return newWrite
    }

    /**
     * Will remove a write at the given path and deeper paths. This will
     * <em>not</em> modify a write at a higher location, which must be removed by
     * calling this method with that path.
     * @param path The path at which a write and all deeper writes should be
     * removed.
     * @return The new FWriteCompound with the removed path.
     */
    @objc public func removeWriteAtPath(_ path: FPath) -> FCompoundWrite {
        if path.isEmpty() {
            return FCompoundWrite.emptyWrite
        } else {
            let newWriteTree = self.writeTree.setTree(.empty(), atPath: path)
            return FCompoundWrite(writeTree: newWriteTree)
        }
    }

    @objc public var rootWrite: FNode? {
        writeTree.value
    }

    /**
     * Returns whether this FCompoundWrite will fully overwrite a node at a given
     * location and can therefore be considered "complete".
     * @param path The path to check for
     * @return Whether there is a complete write at that path.
     */
    @objc public func hasCompleteWriteAtPath(_ path: FPath) -> Bool {
        completeNodeAtPath(path) != nil
    }

    /**
     * Returns a node for a path if and only if the node is a "complete" overwrite
     * at that path. This will not aggregate writes from depeer paths, but will
     * return child nodes from a more shallow path.
     * @param path The path to get a complete write
     * @return The node if complete at that path, or nil otherwise.
     */
    @objc public func completeNodeAtPath(_ path: FPath) -> FNode? {
        guard let rootMost = self.writeTree.findRootMostValueAndPath(path) else {
            return nil
        }
        let relativePath = FPath.relativePath(from: rootMost.path, to: path)
        return rootMost.value.getChild(relativePath)
    }

    // TODO: change into traversal method...
    @objc public var completeChildren: [FNamedNode] {
        var children: [FNamedNode] = []
        if let node = writeTree.value {
            node.enumerateChildren { key, node, _ in
                children.append(FNamedNode(name: key, andNode: node))
            }
        } else {
            writeTree.forEachChild { childKey, childValue in
                if let value = childValue {
                    children.append(FNamedNode(name: childKey, andNode: value))
                }
            }
        }
        return children
    }

    @objc public var childCompoundWrites: [String: FCompoundWrite] {
        var dict: [String: FCompoundWrite] = [:]
        writeTree.forEachChildTree { childKey, childTree in
            dict[childKey] = FCompoundWrite(writeTree: childTree)
        }
        return dict
    }

    @objc public func childCompoundWriteAtPath(_ path: FPath) -> FCompoundWrite {
        if path.isEmpty() {
            return self
        } else {
            if let shadowingNode = self.completeNodeAtPath(path) {
                return FCompoundWrite(writeTree: FImmutableTreeSwift(value: shadowingNode))
            } else {
                return FCompoundWrite(writeTree: writeTree.subtree(atPath: path))
            }
        }
    }

    func applySubtreeWrite(_ subtreeWrite: FImmutableTreeSwift<FNode>, atPath relativePath: FPath, toNode node: FNode) -> FNode {
        if let value = subtreeWrite.value {
            // Since a write there is always a leaf, we're done here.
            return node.updateChild(relativePath, withNewChild: value)
        } else {
            var priorityWrite: FNode? = nil
            var blockNode: FNode = node
            subtreeWrite.forEachChildTree { childKey, childTree in
                if childKey == ".priority" {
                    // Apply priorities at the end so we don't update priorities
                    // for either empty nodes or forget to apply priorities to
                    // empty nodes that are later filled.
                    assert(childTree.value != nil,
                             "Priority writes must always be leaf nodes")
                    priorityWrite = childTree.value

                } else {
                    blockNode = self.applySubtreeWrite(childTree, atPath: relativePath.child(fromString: childKey), toNode: blockNode)
                }
            }
            // If there was a priority write, we only apply it if the node is not
            // empty
            if let priorityWrite = priorityWrite, !blockNode.getChild(relativePath).isEmpty {
                blockNode = blockNode.updateChild(relativePath.child(fromString: ".priority"),
                                                  withNewChild:priorityWrite)
            }
            return blockNode
        }
    }

    /**
     * Applies this FCompoundWrite to a node. The node is returned with all writes
     * from this FCompoundWrite applied to the node.
     * @param node The node to apply this FCompoundWrite to
     * @return The node with all writes applied
     */
    @objc public func applyToNode(_ node: FNode) -> FNode {
        applySubtreeWrite(self.writeTree,
                          atPath:FPath.empty(),
                          toNode:node)

    }

    @objc public func enumerateWrites(_ block: @escaping (FPath, FNode,UnsafeMutablePointer<ObjCBool>) -> Void) {
        var stop: ObjCBool = false
        // TODO: add stop to tree iterator...
        writeTree.forEach { path, value in
            if !stop.boolValue {
                block(path, value, &stop)
            }
        }
    }

    @objc public func valForExport(_ exportFormat: Bool) -> NSDictionary {
        let dictionary = NSMutableDictionary()
        writeTree.forEach { path, value in
            dictionary[path.wireFormat()] = value.val(forExport: exportFormat)
        }
        return dictionary
    }

    /**
     * Return true if this CompoundWrite is empty and therefore does not modify any
     * nodes.
     * @return Whether this CompoundWrite is empty
     */
    @objc public var isEmpty: Bool {
        writeTree.isEmpty()
    }

    public override var description: String {
        valForExport(true).description
    }

    public override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? FCompoundWrite else { return false }
        return valForExport(true).isEqual(other.valForExport(true))
    }

    public override var hash: Int {
        valForExport(true).hash
    }
}
