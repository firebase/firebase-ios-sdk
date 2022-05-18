//
//  File.swift
//  File
//
//  Created by Morten Bek Ditlevsen on 21/09/2021.
//

import SortedCollections
import Foundation

internal struct FImmutableTree<Element> {
    internal private(set) var value: Element?
    // TODO: Perhaps both have a version of this type that is sorted and one that is not. Not all users of the type relies on sorting.
    internal var children: SortedDictionary<String, FImmutableTree<Element>>

    internal init(value: Element?) {
        self.value = value
        self.children = [:]
    }

    internal init(value: Element?, children: SortedDictionary<String, FImmutableTree<Element>>) {
        self.value = value
        self.children = children
    }

    internal static var empty: FImmutableTree<Element> {
        FImmutableTree(value: nil)
    }

    internal var isEmpty: Bool {
        value == nil && children.isEmpty
    }

    internal var childrenIsEmpty: Bool {
        children.isEmpty
    }

    internal func findRootMost(
        matchingPath relativePath: FPath,
        predicate: @escaping (Element) -> Bool
    ) -> (path: FPath, value: Element)? {
        if let value = value, predicate(value) {
            return (path: .empty, value: value)
        }

        guard let front = relativePath.getFront() else {
            return nil
        }
        guard let child = children[front] else {
            // No child matching path
            return nil
        }
        guard let childExistingPathAndValue = child.findRootMost(matchingPath: relativePath.popFront(), predicate: predicate) else {
            return nil
        }
        let fullPath = FPath(with: front).child(childExistingPathAndValue.path)
        return (path: fullPath, value: childExistingPathAndValue.value)
    }

    /**
     * Find, if it exists, the shortest subpath of the given path that points a
     * defined value in the tree
     */
    func findRootMostValueAndPath(_ relativePath: FPath) -> (path: FPath, value: Element)? {
        findRootMost(matchingPath: relativePath, predicate: { _ in true })
    }

    func rootMostValue(onPath path: FPath) -> Element? {
        rootMostValue(onPath: path, matching: { _ in true })
    }

    func rootMostValue(onPath path: FPath, matching predicate: @escaping (Element) -> Bool) -> Element? {
        if let value = value, predicate(value) {
            return value
        }
        guard let front = path.getFront() else { return nil }
        return children[front]?.rootMostValue(onPath: path.popFront(), matching: predicate)
    }

    func leafMostValue(onPath path: FPath) -> Element? {
        leafMostValue(onPath: path, matching: { _ in true })
    }

    func leafMostValue(
        onPath relativePath: FPath,
        matching predicate: @escaping (Element) -> Bool
    ) -> Element? {
        var currentTree = self
        var currentValue = self.value
        relativePath.enumerateComponents(usingBlock: { key, stop in
            guard let child = currentTree.children[key] else {
                stop.pointee = ObjCBool(booleanLiteral: true)
                return
            }
            currentTree = child
            if let treeValue = currentTree.value, predicate(treeValue) {
                currentValue = treeValue
            }
        })
        return currentValue
    }

    func containsValue(matching predicate: @escaping (Element) -> Bool) -> Bool {
        if let value = self.value, predicate(value) {
            return true
        }
        for subtree in children.values {
            if subtree.containsValue(matching: predicate) {
                return true
            }
        }
        return false
    }

    func subtree(atPath relativePath: FPath) -> FImmutableTree<Element> {
        guard let front = relativePath.getFront() else {
            return self
        }
        guard let childTree = children[front] else {
            return .empty
        }
        return childTree.subtree(atPath: relativePath.popFront())
    }

    func setValue(_ newValue: Element?, atPath relativePath: FPath) -> FImmutableTree<Element> {
        guard let front = relativePath.getFront() else {
            return FImmutableTree(value: newValue, children: children)
        }
        let child = children[front] ?? .empty
        let newChild = child.setValue(newValue, atPath: relativePath.popFront())
        var newChildren = children

        newChildren[front] = newChild
        return FImmutableTree(value: self.value, children: newChildren)
    }

    func removeValue(atPath relativePath: FPath) -> FImmutableTree<Element> {
        guard let front = relativePath.getFront() else {
            if children.isEmpty {
                return .empty
            } else {
                return FImmutableTree<Element>(value: nil, children: children)
            }
        }
        guard let child = children[front] else {
            return self
        }
        let newChild = child.removeValue(atPath: relativePath.popFront())
        let newChildren: SortedDictionary<String, FImmutableTree<Element>>
        if newChild.isEmpty {
            var n = children
            _ = n.removeValue(forKey: front)
            newChildren = n
        } else {
            var n = children
            n[front] = newChild
            newChildren = n
        }
        if value == nil && newChildren.isEmpty {
            return .empty
        } else {
            return FImmutableTree<Element>(value: value, children: newChildren)
        }
    }

    func value(atPath relativePath: FPath) -> Element? {
        guard let front = relativePath.getFront() else {
            return value
        }

        guard let child = children[front] else {
            return nil
        }
        return child.value(atPath: relativePath.popFront())
    }

    func setTree(
        _ newTree: FImmutableTree<Element>,
        atPath relativePath: FPath
    ) -> FImmutableTree<Element> {
        guard let front = relativePath.getFront() else {
            return newTree
        }

        let child = children[front] ?? .empty
        let newChild = child.setTree(newTree, atPath: relativePath.popFront())
        let newChildren: SortedDictionary<String, FImmutableTree<Element>>
        if newChild.isEmpty {
            var n = children
            _ = n.removeValue(forKey: front)
            newChildren = n
        } else {
            var n = children
            n[front] = newChild
            newChildren = n
        }
        return FImmutableTree<Element>(value: value, children: newChildren)
    }

    func getChild(key: String) -> FImmutableTree<Element>? {
        children[key]
    }

    func fold<T>(withBlock block: @escaping (_ path: FPath, _ value: Element?, _ foldedChildren: [String : T]) -> T) -> T {
        fold(withPathSoFar: .empty, withBlock: block)
    }

    func fold<T>(
        withPathSoFar pathSoFar: FPath,
        withBlock block: @escaping (_ path: FPath, _ value: Element?, _ foldedChildren: [String : T]) -> T
    ) -> T {
        var accum: [String: T] = [:]
        for (childKey, childTree) in children {
            accum[childKey] = childTree.fold(withPathSoFar: pathSoFar.child(fromString: childKey), withBlock: block)
        }
        return block(pathSoFar, self.value, accum)
    }

    func find<T>(
        onPath path: FPath,
        andApplyBlock block: @escaping (_ path: FPath, _ value: Element) -> T?
    ) -> T? {
        find(onPath: path, pathSoFar: .empty, andApplyBlock: block)
    }

    func find<T>(
        onPath pathToFollow: FPath,
        pathSoFar: FPath,
        andApplyBlock block: @escaping (_ path: FPath, _ value: Element) -> T?
    ) -> T? {
        if let result = value.map({ block(pathSoFar, $0) }) {
            return result
        }

        guard let front = pathToFollow.getFront() else {
            return nil
        }
        guard let nextChild = children[front] else {
            return nil
        }
        return nextChild.find(onPath: pathToFollow.popFront(), pathSoFar: pathSoFar.child(fromString: front), andApplyBlock: block)
    }

    func forEachOn(
        path: FPath,
        whileBlock block: @escaping (_ path: FPath, _ value: Element) -> Bool
    ) -> FPath {
        forEachOn(path, pathSoFar: .empty, whileBlock: block)
    }

    func forEachOn(
        _ pathToFollow: FPath,
        pathSoFar: FPath,
        whileBlock block: @escaping (FPath, Element) -> Bool
    ) -> FPath {
        guard let front = pathToFollow.getFront() else {
            if let value = value {
                _ = block(pathSoFar, value)
            }
            return pathSoFar
        }
        var shouldContinue = true
        if let value = value {
            shouldContinue = block(pathSoFar, value)
        }
        guard shouldContinue else {
            return pathSoFar
        }
        guard let nextChild = children[front] else {
            return pathSoFar
        }
        return nextChild.forEachOn(pathToFollow.popFront(), pathSoFar: pathSoFar.child(fromString: front), whileBlock: block)
    }

    func forEachOn(
        _ path: FPath,
        performBlock block: @escaping (_ path: FPath, _ value: Element) -> Void
    ) -> FImmutableTree<Element> {
        forEachOn(path, pathSoFar: .empty, performBlock: block)
    }

    func forEachOn(
        _ pathToFollow: FPath,
        pathSoFar: FPath,
        performBlock block: @escaping (_ path: FPath, _ value: Element) -> Void
    ) -> FImmutableTree<Element> {
        guard let front = pathToFollow.getFront() else {
            return self
        }
        if let value = value {
            block(pathSoFar, value)
        }
        guard let nextChild = children[front] else {
            return .empty
        }
        return nextChild.forEachOn(pathToFollow.popFront(), pathSoFar: pathSoFar.child(fromString: front), performBlock: block)
    }

    func forEach(_ block: @escaping (_ path: FPath, _ value: Element) -> Void) {
        forEachPathSoFar(.empty, withBlock: block)
    }

    func forEachPathSoFar(
        _ pathSoFar: FPath,
        withBlock block: @escaping (_ path: FPath, _ value: Element) -> Void
    ) {
        for (childKey, childTree) in children {
            childTree.forEachPathSoFar(pathSoFar.child(fromString: childKey), withBlock: block)
        }
        if let value = value {
            block(pathSoFar, value)
        }
    }

    func forEachChild(_ block: @escaping (_ childKey: String, _ childValue: Element?) -> Void) {
        for (childKey, childTree) in children {
            block(childKey, childTree.value)
        }
    }

    func forEachChildTree(_ block: @escaping (_ childKey: String, _ childTree: FImmutableTree<Element>) -> Void) {
        for (childKey, childTree) in children {
            block(childKey, childTree)
        }
    }


//    override func isEqual(_ object: Any?) -> Bool {
//        guard let other = object as? FImmutableTree else {
//            return false
//        }
//        // XXX TODO, THIS MAY BE WRONG
//        if let objcValue = value as? NSObject, let otherObjcValue = value as? NSObject {
//            return objcValue.isEqual(otherObjcValue) && children == other.children
//        }
//        return children == other.children
//    }
//
//    public override var hash: Int {
//      return self.children.hash * 31 + [self.value hash];

//    }
    var description: String {
        var string = "FImmutableTree { value=\(value.map { "\($0)" } ?? "<nil>")"
        string += ", children={"
        for (childKey, childTree) in children {
            let childTreeValue = childTree.value.map { "\($0)" } ?? "<nil>"
            string += " \(childKey)=\(childTreeValue)"
        }
        string += " } }"
        return string
    }

    var debugDescription: String {
        self.description
    }
}

extension FImmutableTree: Equatable where Element: Equatable {
    static func == (lhs: FImmutableTree<Element>, rhs: FImmutableTree<Element>) -> Bool {
        lhs.value == rhs.value && lhs.children == rhs.children
    }


}
