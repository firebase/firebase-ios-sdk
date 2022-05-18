//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 27/09/2021.
//

import SortedCollections
import Foundation

/**
 * Represents a node together with an index. The index and node are updated in
 * unison. In the case where the index does not affect the ordering (i.e. the
 * ordering is identical to the key ordering) this class uses a fallback index
 * to save memory. Everything operating on the index must special case the
 * fallback index.
 */

public struct FIndexedNode {
    struct IndexedNamedNode: Comparable, Equatable {
        static func == (lhs: IndexedNamedNode, rhs: IndexedNamedNode) -> Bool {
            lhs.wrapped == rhs.wrapped && lhs.index === rhs.index
        }

        static func < (lhs: IndexedNamedNode, rhs: IndexedNamedNode) -> Bool {
            lhs.index.compareNamedNode(lhs.wrapped, toNamedNode: rhs.wrapped) == .orderedAscending
        }

        let wrapped: FNamedNode
        let index: FIndex
    }

    enum Wrapper {
        case fallback
        case indexed(SortedSet<IndexedNamedNode>)
    }

    let node: FNode
    let index: FIndex
    var indexed: Wrapper {
        if let initial = initialIndexed {
            return initial
        }
        if index.isEqual(FKeyIndex.keyIndex) {
            return .fallback
        }
        var sawChild = false
        node.enumerateChildren { key, node, stop in
            sawChild = sawChild || self.index.isDefined(on: node)
            if sawChild {
                stop.pointee = ObjCBool(booleanLiteral: true)
            }
        }
        if sawChild {
            var set: SortedSet<IndexedNamedNode> = []
            node.enumerateChildren { [index] key, node, stop in
                let namedNode = FNamedNode(name: key, andNode: node)
                set.insert(IndexedNamedNode(wrapped: namedNode, index: index))
            }

            return .indexed(set)
        } else {
            return .fallback
        }
    }

    let initialIndexed: Wrapper?

    init(node: FNode, index: FIndex = FPriorityIndex.priorityIndex, indexed: Wrapper? = nil) {
        self.node = node
        self.index = index
        self.initialIndexed = indexed
    }

    static func indexedNode(node: FNode) -> FIndexedNode {
        indexedNodeWithNode(node, index: FPriorityIndex.priorityIndex)
    }

    static func indexedNodeWithNode(_ node: FNode, index: FIndex) -> FIndexedNode {
        .init(node: node, index: index)
    }

    func hasIndex(_ index: FIndex) -> Bool {
        self.index.isEqual(index)
    }

    func updateChild(_ key: String, withNewChild newChildNode: FNode) -> Self {
        let newNode = node.updateImmediateChild(key, withNewChild: newChildNode)
        switch indexed {
        case .fallback:
            if !self.index.isDefined(on: newChildNode) {
                // doesn't affect the index, no need to create an index
                return FIndexedNode(node: newNode, index: index, indexed: Wrapper.fallback)
            } else {
                // No need to index yet, index lazily
                #warning("Does this not actually produce the same as the above? Given that the fallback case has a zero cost?")
                return FIndexedNode(node: newNode, index: index)
            }
        case .indexed(var set):
            let oldChild = node.getImmediateChild(key)
            let oldEntry = IndexedNamedNode(wrapped: FNamedNode(name: key, andNode: oldChild), index: index)
            set.remove(oldEntry)
            if !newChildNode.isEmpty {
                let newEntry = IndexedNamedNode(wrapped: FNamedNode(name: key, andNode: newChildNode), index: index)
                set.insert(newEntry)
            }
            return FIndexedNode(node: newNode, index: index, indexed: .indexed(set))
        }

    }
    func updatePriority(_ priority: FNode) -> FIndexedNode {
        FIndexedNode(node: node.updatePriority(priority),
                     index: index,
                     indexed: indexed)
    }

    var firstChild: FNamedNode? {
        guard let childrenNode = node as? FChildrenNode else {
            return nil
        }
        switch indexed {
        case .fallback:
            return childrenNode.firstChild()
        case .indexed(let set):
            return set.first?.wrapped
        }
    }

    var lastChild: FNamedNode? {
        guard let childrenNode = node as? FChildrenNode else {
            return nil
        }
        switch indexed {
        case .fallback:
            return childrenNode.lastChild()
        case .indexed(let set):
            return set.last?.wrapped
        }
    }

    func predecessorForChildKey(_ childKey: String, childNode: FNode, index: FIndex) -> String? {
        if !self.index.isEqual(index) {
            fatalError("Index not available in IndexedNode!")
//            [NSException raise:NSInvalidArgumentException
//                        format:@"Index not available in IndexedNode!"];
        }
        switch indexed {
        case .fallback:
            return node.predecessorChildKey(childKey)
        case .indexed(let set):
            let entry = IndexedNamedNode(wrapped: FNamedNode(name: childKey, andNode: childNode), index: self.index)
            guard let index = set.firstIndex(of: entry), index != set.startIndex else {
                return nil
            }
            return set[set.index(before: index)].wrapped.name
        }
    }

    func enumerateChildrenReverse(_ reverse: Bool, usingBlock block: @escaping (String, FNode, UnsafeMutablePointer<ObjCBool>) -> Void) {
        switch indexed {
        case .fallback:
            node.enumerateChildrenReverse(reverse, usingBlock: block)
        case .indexed(let set):
            var stop = ObjCBool(booleanLiteral: false)
            if reverse {
                for key in set.reversed() {
                    block(key.wrapped.name, key.wrapped.node, &stop)
                    if stop.boolValue {
                        break
                    }
                }
            } else {
                for key in set {
                    block(key.wrapped.name, key.wrapped.node, &stop)
                    if stop.boolValue {
                        break
                    }
                }
            }
        }
    }

    var children: FIndexedNodeChildren {
        .init(node: self)
    }
}

struct FIndexedNodeChildren: Sequence {
    fileprivate let node: FIndexedNode
    fileprivate init(node: FIndexedNode) {
        self.node = node
    }
    func makeIterator() -> NamedNodeIterator {
        .init(node: node)
    }
}

struct NamedNodeIterator: IteratorProtocol {
    typealias Element = FNamedNode

    var _next: () -> FNamedNode?

    fileprivate init(node: FIndexedNode) {
        switch node.indexed {
        case .fallback:
            if let childrenNode = node.node as? FChildrenNode {
                var iterator = childrenNode.children.makeIterator()
                _next = {
                    guard let element = iterator.next() else { return nil }
                    return FNamedNode(name: element.key.key, andNode: element.value)
                }
            } else {
                _next = { nil }
            }
        case .indexed(let set):
            var iterator = set.makeIterator()
            _next = {
                guard let element = iterator.next() else { return nil }
                return element.wrapped
            }
        }
    }

    func next() -> FNamedNode? { _next() }
}

@objc(FIndexedNode) public class FIndexedNodeObjC: NSObject {
    internal let wrapped: FIndexedNode
    @objc public var node: FNode {
        wrapped.node
    }

    @objc public static func indexedNode(node: FNode) -> FIndexedNodeObjC {
        indexedNodeWithNode(node, index: FPriorityIndex.priorityIndex)
    }
    @objc public static func indexedNodeWithNode(_ node: FNode, index: FIndex) -> FIndexedNodeObjC {
        .init(node: node, index: index)
    }

    internal init(wrapped: FIndexedNode) {
        self.wrapped = wrapped
    }

    @objc public init(node: FNode) {
        self.wrapped = FIndexedNode(node: node)
    }

    @objc public init(node: FNode, index: FIndex) {
        self.wrapped = FIndexedNode(node: node, index: index)
    }

    @objc public func hasIndex(_ index: FIndex) -> Bool {
        wrapped.index.isEqual(index)
    }
    @objc public func updateChild(_ key: String, withNewChild newChildNode: FNode) -> FIndexedNodeObjC {
        let x = wrapped.updateChild(key, withNewChild: newChildNode)
        return FIndexedNodeObjC(wrapped: x)
    }
    @objc public func updatePriority(_ priority: FNode) -> FIndexedNodeObjC {
        let updated = wrapped.updatePriority(priority)
        return .init(wrapped: updated)
    }
    @objc public var firstChild: FNamedNode? {
        wrapped.firstChild
    }
    @objc public var lastChild: FNamedNode? {
        wrapped.lastChild
    }
    @objc public func predecessorForChildKey(_ childKey: String, childNode: FNode, index: FIndex) -> String? {
        wrapped.predecessorForChildKey(childKey, childNode: childNode, index: index)
    }
    @objc public func enumerateChildrenReverse(_ reverse: Bool, usingBlock block: @escaping (String, FNode, UnsafeMutablePointer<ObjCBool>) -> Void) {
        wrapped.enumerateChildrenReverse(reverse, usingBlock: block)
    }

    var children: FIndexedNodeChildren { wrapped.children }
}

//@objc public class FIndexedNode: NSObject {
//    @objc public func childEnumerator() -> NSEnumerator {
//        switch indexed {
//        case .fallback:
//            return node.childEnumerator()
//        case .indexed(let set):
//            return ObjectEnumerator(iterator: set.makeIterator())
//        }
//    }
//}

//class ObjectEnumerator: NSEnumerator {
//    var iterator: IndexingIterator<(OrderedSet<FNamedNode>)>
//    init(iterator: IndexingIterator<(OrderedSet<FNamedNode>)>) {
//        self.iterator = iterator
//    }
//
//    override func nextObject() -> Any? {
//        iterator.next()
//    }
//
//}
