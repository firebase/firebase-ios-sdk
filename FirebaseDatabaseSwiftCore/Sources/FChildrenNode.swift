//
//  File.swift
//  File
//
//  Created by Morten Bek Ditlevsen on 21/09/2021.
//

import SortedCollections
import Foundation

@objc public class FEmptyNode: NSObject {
    @objc public static var emptyNode: FNode = FChildrenNode(children: [:])
}

private let kMinName = "[MIN_NAME]"
private let kMaxName = "[MAX_NAME]"

@objc public class FNamedNode: NSObject, NSCopying {
    @objc public var name: String
    @objc public var node: FNode
    @objc public init(name: String, andNode node: FNode) {
        self.name = name
        self.node = node
    }
    @objc public class func nodeWithName(_ name: String, node: FNode) -> FNamedNode {
        FNamedNode(name: name, andNode: node)
    }
    @objc public static var min: FNamedNode = FNamedNode(name: kMinName, andNode: FEmptyNode.emptyNode)
    @objc public static var max: FNamedNode = FNamedNode(name: kMaxName, andNode: FEmptyNode.emptyNode)

    @objc public override func copy() -> Any {
        self
    }

    @objc public func copy(with zone: NSZone? = nil) -> Any {
        self
    }

    @objc public override var description: String {
        "NamedNode[\(name)] \(node)"
    }

    @objc public override func isEqual(_ object: Any?) -> Bool {
        guard let object = object as? FNamedNode else { return false }
        if self === object { return true }
        guard name == object.name else { return false }
        return node.isEqual(object.node)
    }

    @objc public override var hash: Int {
        var hasher = Hasher()
        name.hash(into: &hasher)
        // Obj-C protocol can't conform to hashable, so we convert
        // by calling hash(into:) on the hash value...
        node.hash.hash(into: &hasher)
        return hasher.finalize()
    }
}

struct KeyIndex: Comparable {
    static func < (lhs: KeyIndex, rhs: KeyIndex) -> Bool {
        FUtilitiesSwift.compareKey(lhs.key, rhs.key) == .orderedAscending
    }

    let key: String
}

@objc public class FChildrenNode: NSObject, FNode {

    @objc public func isLeafNode() -> Bool {
        false
    }
    
    @objc public func getPriority() -> FNode {
        priorityNode ?? FEmptyNode.emptyNode
    }

    @objc public func updatePriority(_ priority: FNode) -> FNode {
        if children.isEmpty {
            return FEmptyNode.emptyNode
        } else {
            return FChildrenNode(priority: priority, children: self.children)
        }
    }

    func getImmediateChild(_ childKey: KeyIndex) -> FNode {
        if childKey.key == ".priority" {
            return getPriority()
        } else {
            return children[childKey] ?? FEmptyNode.emptyNode
        }
    }

    @objc public func getImmediateChild(_ childKey: String) -> FNode {
        if childKey == ".priority" {
            return getPriority()
        } else {
            return children[KeyIndex(key: childKey)] ?? FEmptyNode.emptyNode
        }
    }

    @objc public func getChild(_ path: FPath) -> FNode {
        guard let front = path.getFront() else {
            return self
        }
        return getImmediateChild(front).getChild(path.popFront())
    }

    @objc public func predecessorChildKey(_ childKey: String) -> String? {
        let wrapped = KeyIndex(key: childKey)
        guard let keyIndex = children.keys.firstIndex(of: wrapped), keyIndex != children.keys.startIndex else {
            return nil
        }
        return children.keys[children.keys.index(before: keyIndex)].key
    }

    @objc public func updateImmediateChild(_ childKey: String, withNewChild newChildNode: FNode) -> FNode {
        guard childKey != ".priority" else {
            return updatePriority(newChildNode)
        }

        var newChildren = self.children
        if newChildNode.isEmpty {
            _ = newChildren.removeValue(forKey: KeyIndex(key: childKey))
        } else {
            newChildren[KeyIndex(key: childKey)] = newChildNode
        }

        if newChildren.isEmpty {
            return FEmptyNode.emptyNode
        } else {
            return FChildrenNode(priority: getPriority(), children: newChildren)
        }
    }

    @objc public func updateChild(_ path: FPath, withNewChild newChildNode: FNode) -> FNode {
        guard let front = path.getFront() else {
            return newChildNode
        }

        assert(front != ".priority" || path.length() == 1, ".priority must be the last token in a path.")
        let newImmediateChild = getImmediateChild(front).updateChild(path.popFront(), withNewChild: newChildNode)
        return updateImmediateChild(front, withNewChild: newImmediateChild)
    }

    @objc public func hasChild(_ childKey: String) -> Bool {
        !getImmediateChild(childKey).isEmpty
    }

    @objc public var isEmpty: Bool {
        children.isEmpty
    }

    @objc public func numChildren() -> Int {
        children.count
    }

    @objc public func val() -> Any {
        return val(forExport: false)
    }

    @objc public func val(forExport exp: Bool) -> Any {
        guard !isEmpty else {
            return NSNull()
        }
        var numKeys = 0
        var maxKey = 0
        var allIntegerKeys = true
        let obj = NSMutableDictionary(capacity: children.count)
        for (key, childNode) in children {
            obj.setObject(childNode.val(forExport: exp), forKey: key.key as NSString)
            numKeys += 1

            // If we already found a string key, don't bother with any of this
            if !allIntegerKeys { continue }

            // Treat leading zeroes that are not exactly "0" as strings
            if key.key.first == "0" && key.key.count > 1 {
                allIntegerKeys = false
                continue
            }
            if let keyAsInt = FUtilitiesSwift.intForString(key.key) {
                maxKey = max(maxKey, keyAsInt)
            } else {
                allIntegerKeys = false
            }
        }
        if !exp && allIntegerKeys && maxKey < 2 * numKeys {
            // convert to an array
            let array = NSMutableArray(capacity: maxKey + 1)
            for i in 0...maxKey {
                if let child = obj["\(i)"] {
                    array.add(child)
                } else {
                    array.add(NSNull())
                }
            }
            return array
        } else {
            if exp && !self.getPriority().isEmpty {
                obj[".priority"] = getPriority().val()
            }
            return obj
        }
    }

    @objc public func dataHash() -> String {
        if let hash = lazyHash {
            return hash
        }
        var toHash = ""

        if !getPriority().isEmpty {
            toHash += "priority:"
            FSnapshotUtilitiesSwift
                .appendHashRepresentation(for: self.getPriority(),
                                             to: &toHash,
                                             hashVersion: .v1)
            toHash += ":"
        }
        var sawPriority = false
        for node in children.values {
            sawPriority = sawPriority || node.getPriority().isEmpty
            if sawPriority { break }
        }
        if sawPriority {
            var array: [FNamedNode] = []
            for (key, node) in children {
                array.append(FNamedNode(name: key.key, andNode: node))
            }
            array.sort { a, b in
                FPriorityIndex
                    .priorityIndex
                    .compareNamedNode(a, toNamedNode: b) == .orderedAscending
            }
            for namedNode in array {
                let childHash = namedNode.node.dataHash()
                if !children.isEmpty {
                    toHash += ":\(namedNode.name):\(childHash)"
                }
            }
        } else {
            for (key, node) in children {
                let childHash = node.dataHash()
                if !childHash.isEmpty {
                    toHash += ":\(key.key):\(childHash)"
                }
            }
        }

        let calculatedHash = toHash.isEmpty ? "" : FStringUtilitiesSwift.base64EncodedSha1(toHash)
        lazyHash = calculatedHash
        return calculatedHash
    }

    @objc public func compare(_ other: FNode) -> ComparisonResult {
        
        // children nodes come last, unless this is actually an empty node, then we
        // come first.
        if isEmpty {
            if other.isEmpty {
                return .orderedSame
            } else {
                return .orderedAscending
            }
        } else if (other.isLeafNode() || other.isEmpty) {
            return .orderedDescending
        } else if (other === FMaxNode.maxNode) {
            return .orderedAscending
        } else {
            // Must be another node with children.
            return .orderedSame
        }
    }

    @objc public func enumerateChildren(usingBlock block: @escaping (String, FNode, UnsafeMutablePointer<ObjCBool>) -> Void) {
        var stop = ObjCBool(booleanLiteral: false)
        for (key, value) in children {
            block(key.key, value, &stop)
            if stop.boolValue { break }
        }
    }

    @objc public func enumerateChildrenReverse(_ reverse: Bool, usingBlock block: @escaping (String, FNode, UnsafeMutablePointer<ObjCBool>) -> Void) {
        var stop = ObjCBool(booleanLiteral: false)
        if reverse {
            for (key, value) in children.reversed() {
                block(key.key, value, &stop)
                if stop.boolValue { break }
            }
        } else {
            for (key, value) in children {
                block(key.key, value, &stop)
                if stop.boolValue { break }
            }
        }
    }

//    @objc public func childEnumerator() -> NSEnumerator {
//        NodeEnumerator(iterator: children.makeIterator(), node: self)
//    }

    var children: SortedDictionary<KeyIndex, FNode>
    var priorityNode: FNode?
    var lazyHash: String?

    init(children: SortedDictionary<KeyIndex, FNode>) {
        self.children = children
    }

    public override var description: String {
        "FChildrenNode: \(children)"
    }

    public override var hash: Int {
        var hasher = Hasher()
        for (key, node) in children {
            key.key.hash(into: &hasher)
            node.hash.hash(into: &hasher)
        }
        priorityNode?.hash.hash(into: &hasher)
        return hasher.finalize()
    }

    public override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? FNode else { return false }
        if other === self { return true }
        if other.isLeafNode() { return false }
        if self.isEmpty && other.isEmpty {
            // Empty nodes do not have priority
            return true
        }
        guard self.getPriority().isEqual(other.getPriority()) else {
            return false
        }
        guard let otherChildNode = other as? FChildrenNode else { return false }

        guard self.children.count == otherChildNode.children.count else { return false }
        for (key, node) in children {
            let child = otherChildNode.getImmediateChild(key.key)
            guard child.isEqual(node) else {
                return false
            }
        }
        return true
    }


    init(
        priority: FNode,
        children: SortedDictionary<KeyIndex, FNode>
    ) {
        self.children = children
        self.priorityNode = priority
    }

    @objc public override init() {
        self.children = [:]
        self.priorityNode = nil
    }

    @objc public func enumerateChildrenAndPriority(usingBlock block: @escaping (String, FNode, UnsafeMutablePointer<ObjCBool>) -> Void) {
        if getPriority().isEmpty {
            enumerateChildren(usingBlock: block)
        } else {
            var passedPriorityKey = false
            enumerateChildren { key, node, stop in
                if !passedPriorityKey {
                    if FUtilitiesSwift.compareKey(key, ".priority") == .orderedDescending {
                        passedPriorityKey = true
                    }
                    if passedPriorityKey {
                        var stopAfterPriority = ObjCBool(booleanLiteral: false)
                        block(".priority", self.getPriority(), &stopAfterPriority)
                        if stopAfterPriority.boolValue {
                            // MBD: Is this correct? Shouldn't we in fact stop the
                            // whole thing here instead of returning, which basically just
                            // skips the next call to the block?
                            return
                        }
                    }
                }
                block(key, node, stop)
            }
        }
    }

    @objc public func firstChild() -> FNamedNode? {
        guard let first = children.keys.first else {
            return nil
        }
        return FNamedNode(name: first.key, andNode: getImmediateChild(first.key))
    }

    @objc public func lastChild() -> FNamedNode? {
        guard let last = children.keys.last else {
            return nil
        }
        return FNamedNode(name: last.key, andNode: getImmediateChild(last.key))
    }
}

@objc public class FMaxNode: FChildrenNode {
    @objc public static var maxNode = FMaxNode()
    public override func compare(_ other: FNode) -> ComparisonResult {
        if other === self { return .orderedSame }
        else { return .orderedDescending }
    }

    public override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? FMaxNode else { return false }
        return other === self
    }

    public override func getImmediateChild(_ childKey: String) -> FNode {
        FEmptyNode.emptyNode
    }

    // Hmm, is this correct?
    public override var isEmpty: Bool {
        false
    }
}
