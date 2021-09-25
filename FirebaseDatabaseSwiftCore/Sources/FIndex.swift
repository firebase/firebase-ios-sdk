//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 22/09/2021.
//

import Foundation

@objc public protocol FIndex: NSObjectProtocol, NSCopying {
    func compareKey(
            _ key1: String,
            andNode node1: FNode,
            toOtherKey key2: String,
            andNode node2: FNode
        ) -> ComparisonResult
    func compareKey(
            _ key1: String,
            andNode node1: FNode,
            toOtherKey key2: String,
            andNode node2: FNode,
            reverse: Bool
        ) -> ComparisonResult
    func compareNamedNode(
             _ namedNode1: FNamedNode,
            toNamedNode namedNode2: FNamedNode
        ) -> ComparisonResult
    func isDefined(on node: FNode) -> Bool
    func indexedValueChangedBetween(_ oldNode: FNode, and newNode: FNode) -> Bool
    var minPost: FNamedNode { get }
    var maxPost: FNamedNode { get }
    func makePost(_ indexValue: FNode, name: String) -> FNamedNode
    var queryDefinition: String { get }
}

@objc public class FKeyIndex: NSObject, FIndex {
    public func compareKey(_ key1: String, andNode node1: FNode, toOtherKey key2: String, andNode node2: FNode) -> ComparisonResult {
        FUtilitiesSwift.compareKey(key1, key2)
    }

    public func compareKey(_ key1: String, andNode node1: FNode, toOtherKey key2: String, andNode node2: FNode, reverse: Bool) -> ComparisonResult {
        if reverse {
            return FUtilitiesSwift.compareKey(key2, key1)
        } else {
            return FUtilitiesSwift.compareKey(key1, key2)
        }
    }

    public func compareNamedNode(_ namedNode1: FNamedNode, toNamedNode namedNode2: FNamedNode) -> ComparisonResult {
        compareKey(namedNode1.name, andNode: namedNode1.node, toOtherKey: namedNode2.name, andNode: namedNode2.node)
    }

    public func isDefined(on node: FNode) -> Bool {
        true
    }

    public func indexedValueChangedBetween(_ oldNode: FNode, and newNode: FNode) -> Bool {
        false // The key for a node never changes.
    }

    public let minPost: FNamedNode = .min

    public func makePost(_ indexValue: FNode, name: String) -> FNamedNode {
        let key = indexValue.val() as? String
        assert(key != nil, "KeyIndex indexValue must always be a string.")

        // We just use empty node, but it'll never be compared, since our comparator
        // only looks at name.
        return FNamedNode(name: key ?? "", andNode: FEmptyNode.emptyNode)
    }

    public var queryDefinition: String = ".key"

    public func copy(with zone: NSZone? = nil) -> Any {
        self
    }

    public override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? FKeyIndex else { return false }
        return other === self
    }

    public override var description: String {
        "FKeyIndex"
    }

    public override var hash: Int {
        ".key".hash
    }

    public let maxPost: FNamedNode
    private override init() {
        self.maxPost = FNamedNode(name: FUtilitiesSwift.maxName, andNode: FEmptyNode.emptyNode)
        super.init()
    }

    @objc public static var keyIndex: FIndex = FKeyIndex()
}

@objc public class FValueIndex: NSObject, FIndex {
    public func compareKey(_ key1: String, andNode node1: FNode, toOtherKey key2: String, andNode node2: FNode) -> ComparisonResult {
        let indexCmp = node1.compare(node2)
        if indexCmp == .orderedSame {
            return FUtilitiesSwift.compareKey(key1, key2)
        } else {
            return indexCmp
        }
    }

    public func compareKey(_ key1: String, andNode node1: FNode, toOtherKey key2: String, andNode node2: FNode, reverse: Bool) -> ComparisonResult {
        if reverse {
            return compareKey(key2, andNode: node2, toOtherKey: key1, andNode: node1)
        } else {
            return compareKey(key1, andNode: node1, toOtherKey: key2, andNode: node2)
        }
    }

    public func compareNamedNode(_ namedNode1: FNamedNode, toNamedNode namedNode2: FNamedNode) -> ComparisonResult {
        FUtilitiesSwift.compareKey(namedNode1.name, namedNode2.name)
    }

    public func isDefined(on node: FNode) -> Bool {
        true
    }

    public func indexedValueChangedBetween(_ oldNode: FNode, and newNode: FNode) -> Bool {
        !oldNode.isEqual(newNode)
    }

    public let minPost: FNamedNode = .min
    public let maxPost: FNamedNode = .max

    public func makePost(_ indexValue: FNode, name: String) -> FNamedNode {
        FNamedNode(name: name, andNode: indexValue)
    }

    public var queryDefinition: String = ".value"

    public func copy(with zone: NSZone? = nil) -> Any {
        self
    }

    public override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? FValueIndex else { return false }
        return other === self
    }

    public override var description: String {
        "FValueIndex"
    }

    public override var hash: Int {
        ".value".hash
    }

    private override init() {
        super.init()
    }

    @objc public static var valueIndex: FIndex = FValueIndex()
}

@objc public class FPriorityIndex: NSObject, FIndex {
    public func compareKey(_ key1: String, andNode node1: FNode, toOtherKey key2: String, andNode node2: FNode) -> ComparisonResult {
        let child1 = node1.getPriority()
        let child2 = node2.getPriority()

        let indexCmp = child1.compare(child2)
        if indexCmp == .orderedSame {
            return FUtilitiesSwift.compareKey(key1, key2)
        } else {
            return indexCmp
        }
    }

    public func compareKey(_ key1: String, andNode node1: FNode, toOtherKey key2: String, andNode node2: FNode, reverse: Bool) -> ComparisonResult {
        if reverse {
            return compareKey(key2, andNode: node2, toOtherKey: key1, andNode: node1)
        } else {
            return compareKey(key1, andNode: node1, toOtherKey: key2, andNode: node2)
        }
    }

    public func compareNamedNode(_ namedNode1: FNamedNode, toNamedNode namedNode2: FNamedNode) -> ComparisonResult {
        FUtilitiesSwift.compareKey(namedNode1.name, namedNode2.name)
    }

    public func isDefined(on node: FNode) -> Bool {
        !node.getPriority().isEmpty
    }

    public func indexedValueChangedBetween(_ oldNode: FNode, and newNode: FNode) -> Bool {
        let oldValue = oldNode.getPriority()
        let newValue = newNode.getPriority()
        return !oldValue.isEqual(newValue)
    }

    public let minPost: FNamedNode = .min
    public var maxPost: FNamedNode {
        makePost(FMaxNode.maxNode, name: FUtilitiesSwift.maxName)
    }

    public func makePost(_ indexValue: FNode, name: String) -> FNamedNode {
        let node = FLeafNode(value: "[PRIORITY-POST]" as NSString, withPriority: indexValue)
        return FNamedNode(name: name, andNode: node)
    }

    public var queryDefinition: String = ".priority"

    public func copy(with zone: NSZone? = nil) -> Any {
        self
    }

    public override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? FPriorityIndex else { return false }
        return other === self
    }

    public override var description: String {
        "FPriorityIndex"
    }

    public override var hash: Int {
        // Should we follow the style of the other FIndex implementations
        // or the original code?
        /* // chosen by a fair dice roll. Guaranteed to be random
         return 3155577;*/
        ".priority".hash
    }

    private override init() {
        super.init()
    }

    @objc public static var priorityIndex: FIndex = FPriorityIndex()
}

@objc public class FPathIndex: NSObject, FIndex {
    public func compareKey(_ key1: String, andNode node1: FNode, toOtherKey key2: String, andNode node2: FNode) -> ComparisonResult {

        let child1 = node1.getChild(path)
        let child2 = node2.getChild(path)

        let indexCmp = child1.compare(child2)
        if indexCmp == .orderedSame {
            return FUtilitiesSwift.compareKey(key1, key2)
        } else {
            return indexCmp
        }
    }

    public func compareKey(_ key1: String, andNode node1: FNode, toOtherKey key2: String, andNode node2: FNode, reverse: Bool) -> ComparisonResult {
        if reverse {
            return compareKey(key2, andNode: node2, toOtherKey: key1, andNode: node1)
        } else {
            return compareKey(key1, andNode: node1, toOtherKey: key2, andNode: node2)
        }
    }

    public func compareNamedNode(_ namedNode1: FNamedNode, toNamedNode namedNode2: FNamedNode) -> ComparisonResult {
        FUtilitiesSwift.compareKey(namedNode1.name, namedNode2.name)
    }

    public func isDefined(on node: FNode) -> Bool {
        !node.getChild(path).isEmpty
    }

    public func indexedValueChangedBetween(_ oldNode: FNode, and newNode: FNode) -> Bool {
        let oldValue = oldNode.getChild(path)
        let newValue = newNode.getChild(path)
        return oldValue.compare(newValue) != .orderedSame
    }

    public let minPost: FNamedNode = .min
    public var maxPost: FNamedNode {
        makePost(FMaxNode.maxNode, name: FUtilitiesSwift.maxName)
    }

    public func makePost(_ indexValue: FNode, name: String) -> FNamedNode {
        let node = FEmptyNode.emptyNode
            .updateChild(path, withNewChild: indexValue)
        return FNamedNode(name: name, andNode: node)
    }

    public var queryDefinition: String { path.wireFormat() }

    public func copy(with zone: NSZone? = nil) -> Any {
        // Safe since we're immutable.
        self
    }

    public override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? FPathIndex else { return false }
        return path.isEqual(other.path)
    }

    public override var description: String {
        "FPathIndex(\(path))"
    }

    public override var hash: Int {
        path.hash
    }

    @objc public init(path: FPath) {
        if path.isEmpty() || path.getFront() == ".priority" {
            fatalError("Invalid path for PathIndex: \(path)")
        }

        self.path = path
        super.init()
    }
    let path: FPath
}

@objc public class FIndexFactory: NSObject {
    @objc public class func indexFromQueryDefinition(_ definition: String) -> FIndex {
        switch definition {
        case ".key":
            return FKeyIndex.keyIndex
        case ".value":
            return FValueIndex.valueIndex
        case ".priority":
            return FPriorityIndex.priorityIndex
        default:
            return FPathIndex(path: FPath(with: definition))
        }
    }
}
