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

enum FIndexSwift: Equatable {
    case key
    case priority
    case value
    case path(FPath)

    func compare(lhs: (key: String, node: FNode), rhs: (key: String, node: FNode)) -> ComparisonResult {
        switch self {
        case .key:
            return FUtilitiesSwift.compareKey(lhs.key, rhs.key)
        case .value:
            let indexCmp = lhs.node.compare(rhs.node)
            if indexCmp == .orderedSame {
                return FUtilitiesSwift.compareKey(lhs.key, rhs.key)
            } else {
                return indexCmp
            }
        case .priority:
            let lhsChild = lhs.node.getPriority()
            let rhsChild = rhs.node.getPriority()

            let indexCmp = lhsChild.compare(rhsChild)
            if indexCmp == .orderedSame {
                return FUtilitiesSwift.compareKey(lhs.key, rhs.key)
            } else {
                return indexCmp
            }
        case .path(let path):
            let lhsChild = lhs.node.getChild(path)
            let rhsChild = rhs.node.getChild(path)

            let indexCmp = lhsChild.compare(rhsChild)
            if indexCmp == .orderedSame {
                return FUtilitiesSwift.compareKey(lhs.key, rhs.key)
            } else {
                return indexCmp
            }
        }
    }

    func isDefined(on node: FNode) -> Bool {
        switch self {
        case .key:
            return true
        case .value:
            return true
        case .priority:
            return !node.getPriority().isEmpty
        case .path(let path):
            return !node.getChild(path).isEmpty
        }
    }

    func indexedValueChanged(between oldNode: FNode, and newNode: FNode) -> Bool {
        switch self {
        case .key:
            // The key for a node never changes.
            return false
        case .value:
            return !oldNode.isEqual(newNode)

        case .priority:
            let oldValue = oldNode.getPriority()
            let newValue = newNode.getPriority()
            return !oldValue.isEqual(newValue)

        case .path(let path):
            let oldValue = oldNode.getChild(path)
            let newValue = newNode.getChild(path)
            return oldValue.compare(newValue) != .orderedSame
        }
    }

    var minPost: FNamedNode { .min }
    var maxPost: FNamedNode {
        switch self {
        case .key:
            return FNamedNode(name: FUtilitiesSwift.maxName, andNode: FEmptyNode.emptyNode)
        case .value:
            return .max
        case .priority:
            return makePost(FMaxNode.maxNode, name: FUtilitiesSwift.maxName)
        case .path:
            return makePost(FMaxNode.maxNode, name: FUtilitiesSwift.maxName)
        }
    }

    func makePost(_ indexValue: FNode, name: String) -> FNamedNode {
        switch self {
        case .key:
            let key = indexValue.val() as? String
            assert(key != nil, "KeyIndex indexValue must always be a string.")

            // We just use empty node, but it'll never be compared, since our comparator
            // only looks at name.
            return FNamedNode(name: key ?? "", andNode: FEmptyNode.emptyNode)

        case .value:
            return FNamedNode(name: name, andNode: indexValue)

        case .priority:
            let node = FLeafNode(value: "[PRIORITY-POST]" as NSString, withPriority: indexValue)
            return FNamedNode(name: name, andNode: node)

        case .path(let path):
            let node = FEmptyNode.emptyNode
                .updateChild(path, withNewChild: indexValue)
            return FNamedNode(name: name, andNode: node)
        }
    }

    var description: String {
        switch self {
        case .key:
            return "FKeyIndex"
        case .priority:
            return "FPriorityIndex"
        case .value:
            return "FValueIndex"
        case .path(let path):
            return "FPathIndex(\(path))"
        }
    }

    var queryDefinition: String {
        switch self {
        case .key:
            return ".key"
        case .value:
            return ".value"
        case .priority:
            return ".priority"
        case .path(let path):
            return path.wireFormat()
        }
    }

    var objc: FIndex {
        switch self {
        case .key:
            return FKeyIndex.keyIndex
        case .value:
            return FValueIndex.valueIndex
        case .priority:
            return FPriorityIndex.priorityIndex
        case .path(let path):
            return FPathIndex(path: path)
        }
    }
}

extension FIndexSwift {
    func compareNamedNode(lhs: FNamedNode, rhs: FNamedNode) -> ComparisonResult {
        compare(lhs: (key: lhs.name, node: lhs.node), rhs: (key: rhs.name, node: rhs.node))
    }
    func compare(lhs: (key: String, node: FNode), rhs: (key: String, node: FNode), reversed: Bool) -> ComparisonResult {
        if reversed {
            return compare(lhs: rhs, rhs: lhs)
        } else {
            return compare(lhs: lhs, rhs: rhs)
        }
    }
}

@objc public class FKeyIndex: FIndexBase {

    public override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? FKeyIndex else { return false }
        return other === self
    }

    public override var hash: Int {
        ".key".hash
    }

    private init() {
        super.init(index: .key)
    }

    @objc public static var keyIndex: FIndex = FKeyIndex()
}

@objc public class FValueIndex: FIndexBase {

    public override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? FValueIndex else { return false }
        return other === self
    }

    public override var hash: Int {
        ".value".hash
    }

    private init() {
        super.init(index: .value)
    }

    @objc public static var valueIndex: FIndex = FValueIndex()
}

@objc public class FPriorityIndex: FIndexBase {

    public override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? FPriorityIndex else { return false }
        return other === self
    }

    public override var hash: Int {
        // Should we follow the style of the other FIndex implementations
        // or the original code?
        /* // chosen by a fair dice roll. Guaranteed to be random
         return 3155577;*/
        ".priority".hash
    }

    private init() {
        super.init(index: .priority)
    }

    @objc public static var priorityIndex: FPriorityIndex = FPriorityIndex()
}

@objc public class FIndexBase: NSObject, FIndex {
    internal let index: FIndexSwift

    @objc(copyWithZone:) public func copy(with zone: NSZone? = nil) -> Any {
        // Safe since we're immutable.
        self
    }

    @objc public func compareKey(_ key1: String, andNode node1: FNode, toOtherKey key2: String, andNode node2: FNode) -> ComparisonResult {
        index.compare(lhs: (key: key1, node: node1), rhs: (key: key2, node: node2))
    }

    @objc public func compareKey(_ key1: String, andNode node1: FNode, toOtherKey key2: String, andNode node2: FNode, reverse: Bool) -> ComparisonResult {
        index.compare(lhs: (key: key1, node: node1), rhs: (key: key2, node: node2), reversed: reverse)
    }

    @objc public func compareNamedNode(_ namedNode1: FNamedNode, toNamedNode namedNode2: FNamedNode) -> ComparisonResult {
        index.compareNamedNode(lhs: namedNode1, rhs: namedNode2)
    }

    @objc public func isDefined(on node: FNode) -> Bool {
        index.isDefined(on: node)
    }

    @objc public func indexedValueChangedBetween(_ oldNode: FNode, and newNode: FNode) -> Bool {
        index.indexedValueChanged(between: oldNode, and: newNode)
    }

    @objc public var minPost: FNamedNode { index.minPost }
    @objc public var maxPost: FNamedNode { index.maxPost }
    @objc public func makePost(_ indexValue: FNode, name: String) -> FNamedNode {
        index.makePost(indexValue, name: name)
    }

    public override var description: String {
        index.description
    }

    @objc public var queryDefinition: String {
        index.queryDefinition
    }

    fileprivate init(index: FIndexSwift) {
        self.index = index
    }
}

@objc public class FPathIndex: FIndexBase {

    public override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? FPathIndex else { return false }
        return path.isEqual(other.path)
    }

    public override var hash: Int {
        path.hash
    }

    @objc public init(path: FPath) {
        if path.isEmpty || path.getFront() == ".priority" {
            fatalError("Invalid path for PathIndex: \(path)")
        }
        self.path = path
        super.init(index: .path(path))
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
