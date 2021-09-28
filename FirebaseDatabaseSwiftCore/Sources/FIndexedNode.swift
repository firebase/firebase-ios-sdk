//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 27/09/2021.
//

import Collections
import Foundation

/**
 * Represents a node together with an index. The index and node are updated in
 * unison. In the case where the index does not affect the ordering (i.e. the
 * ordering is identical to the key ordering) this class uses a fallback index
 * to save memory. Everything operating on the index must special case the
 * fallback index.
 */

@objc public class FIndexedNode: NSObject {
    enum Wrapper {
        case fallback
        case indexed(OrderedSet<FNamedNode>)
    }
    @objc public let node: FNode
    let index: FIndex
    lazy var indexed: Wrapper = {
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
            var set: OrderedSet<FNamedNode> = []
            node.enumerateChildren { key, node, stop in
                let namedNode = FNamedNode(name: key, andNode: node)
                set.append(namedNode)
            }

            // SORT
            set.sort { a, b in
                index.compareNamedNode(a, toNamedNode: b) == .orderedAscending
            }

            return .indexed(set)
        } else {
            return .fallback
        }
    }()
    let initialIndexed: Wrapper?

    init(node: FNode, index: FIndex) {
        self.node = node
        self.index = index
        self.initialIndexed = nil
    }
    init(node: FNode, index: FIndex, indexed: Wrapper) {
        self.node = node
        self.index = index
        self.initialIndexed = indexed
    }
    @objc public static func indexedNode(node: FNode) -> FIndexedNode {
        indexedNodeWithNode(node, index: FPriorityIndex.priorityIndex)
    }
    @objc public static func indexedNodeWithNode(_ node: FNode, index: FIndex) -> FIndexedNode {
        FIndexedNode(node: node, index: index)
    }
    @objc public func hasIndex(_ index: FIndex) -> Bool {
        self.index.isEqual(index)
    }

    @objc public func updateChild(_ key: String, withNewChild newChildNode: FNode) -> FIndexedNode {
        let newNode = node.updateImmediateChild(key, withNewChild: newChildNode)
        switch indexed {
        case .fallback:
            if !self.index.isDefined(on: newChildNode) {
                // doesn't affect the index, no need to create an index
                return FIndexedNode(node: newNode, index: index, indexed: .fallback)
            } else {
                // No need to index yet, index lazily
                #warning("Does this not actually produce the same as the above? Given that the fallback case has a zero cost?")
                return FIndexedNode(node: newNode, index: index)
            }
        case .indexed(var set):
            let oldChild = node.getImmediateChild(key)
            set.remove(FNamedNode(name: key, andNode: oldChild))
            if !newChildNode.isEmpty {
                set.append(FNamedNode(name: key, andNode: newChildNode))
                // SORT
                set.sort { a, b in
                    index.compareNamedNode(a, toNamedNode: b) == .orderedAscending
                }
            }
            return FIndexedNode(node: newNode, index: index, indexed: .indexed(set))
        }

    }
    @objc public func updatePriority(_ priority: FNode) -> FIndexedNode {
        FIndexedNode(node: node.updatePriority(priority),
                     index: index,
                     indexed: indexed)
    }

    @objc public var firstChild: FNamedNode? {
        guard let childrenNode = node as? FChildrenNode else {
            return nil
        }
        switch indexed {
        case .fallback:
            return childrenNode.firstChild()
        case .indexed(let set):
            return set.first
        }
    }

    @objc public var lastChild: FNamedNode? {
        guard let childrenNode = node as? FChildrenNode else {
            return nil
        }
        switch indexed {
        case .fallback:
            return childrenNode.lastChild()
        case .indexed(let set):
            return set.last
        }
    }

    @objc public func predecessorForChildKey(_ childKey: String, childNode: FNode, index: FIndex) -> String? {
        if !self.index.isEqual(index) {
            fatalError("Index not available in IndexedNode!")
//            [NSException raise:NSInvalidArgumentException
//                        format:@"Index not available in IndexedNode!"];
        }
        switch indexed {
        case .fallback:
            return node.predecessorChildKey(childKey)
        case .indexed(let set):
            guard let index = set.firstIndex(of: FNamedNode(name: childKey, andNode: childNode)), index > 0 else {
                return nil
            }
            return set.elements[index - 1].name
        }
    }

    @objc public func enumerateChildrenReverse(_ reverse: Bool, usingBlock block: @escaping (String, FNode, UnsafeMutablePointer<ObjCBool>) -> Void) {
        switch indexed {
        case .fallback:
            node.enumerateChildrenReverse(reverse, usingBlock: block)
        case .indexed(let set):
            var stop = ObjCBool(booleanLiteral: false)
            if reverse {
                for key in set.reversed() {
                    block(key.name, key.node, &stop)
                    if stop.boolValue {
                        break
                    }
                }
            } else {
                for key in set {
                    block(key.name, key.node, &stop)
                    if stop.boolValue {
                        break
                    }
                }
            }
        }

    }
    @objc public func childEnumerator() -> NSEnumerator {
        switch indexed {
        case .fallback:
            return node.childEnumerator()
        case .indexed(let set):
            return ObjectEnumerator(iterator: set.makeIterator())
        }
    }
}
