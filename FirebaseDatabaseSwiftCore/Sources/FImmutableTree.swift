//
//  File.swift
//  File
//
//  Created by Morten Bek Ditlevsen on 21/09/2021.
//

import Collections
import Foundation

@objc public class FImmutableTree: NSObject {
    @objc public private(set) var value: Any?
    // TODO: Replace with SortedDictionary when it's fully baked.
    // This serves as an implementation placeholder for now.
    internal var children: OrderedDictionary<String, FImmutableTree>

    @objc public init(value: Any?) {
        self.value = value
        self.children = [:]
    }

    internal init(value: Any?, children: OrderedDictionary<String, FImmutableTree>) {
        self.value = value
        self.children = children
    }
//    @objc public init(
//        value aValue: Any,
//        children childrenMap: FImmutableSortedDictionary
//    ) {
//    }

    @objc public class func empty() -> FImmutableTree {
        FImmutableTree(value: nil)
    }

    @objc public func isEmpty() -> Bool {
        value == nil && children.isEmpty
    }

    @objc public func childrenIsEmpty() -> Bool {
        children.isEmpty
    }

    @objc public func findRootMost(
        matchingPath relativePath: FPath,
        predicate: @escaping (Any) -> Bool
    ) -> FTuplePathValue? {
        if let value = value, predicate(value) {
            return FTuplePathValue(path: .empty(), value: value)
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
        return FTuplePathValue(path: fullPath, value: childExistingPathAndValue.value)
    }

    /**
     * Find, if it exists, the shortest subpath of the given path that points a
     * defined value in the tree
     */
    @objc public func findRootMostValueAndPath(_ relativePath: FPath) -> FTuplePathValue? {
        findRootMost(matchingPath: relativePath, predicate: { _ in true })
    }

    @objc public func rootMostValue(onPath path: FPath) -> Any? {
        rootMostValue(onPath: path, matching: { _ in true })
    }

    @objc public func rootMostValue(onPath path: FPath, matching predicate: @escaping (Any) -> Bool) -> Any? {
        if let value = value, predicate(value) {
            return value
        }
        guard let front = path.getFront() else { return nil }
        return children[front]?.rootMostValue(onPath: path.popFront(), matching: predicate)
    }

    @objc public func leafMostValue(onPath path: FPath) -> Any? {
        leafMostValue(onPath: path, matching: { _ in true })
    }

    @objc public func leafMostValue(
        onPath relativePath: FPath,
        matching predicate: @escaping (Any?) -> Bool
    ) -> Any? {
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

    @objc public func containsValue(matching predicate: @escaping (Any) -> Bool) -> Bool {
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

    @objc public func subtree(atPath relativePath: FPath) -> FImmutableTree {
        guard let front = relativePath.getFront() else {
            return self
        }
        guard let childTree = children[front] else {
            return FImmutableTree.empty()
        }
        return childTree.subtree(atPath: relativePath.popFront())
    }

    @objc public func setValue(_ newValue: Any?, atPath relativePath: FPath) -> FImmutableTree {
        guard let front = relativePath.getFront() else {
            return FImmutableTree(value: newValue, children: children)
        }
        let child = children[front] ?? .empty()
        let newChild = child.setValue(newValue, atPath: relativePath.popFront())
        var newChildren = children

        // TODO: Replace with SortedDictionary and just do an insert here!
        newChildren[front] = newChild
        newChildren.sort()
        return FImmutableTree(value: self.value, children: newChildren)
    }

    @objc public func removeValue(atPath relativePath: FPath) -> FImmutableTree {
        guard let front = relativePath.getFront() else {
            if children.isEmpty {
                return .empty()
            } else {
                return FImmutableTree(value: nil, children: children)
            }
        }
        guard let child = children[front] else {
            return self
        }
        let newChild = child.removeValue(atPath: relativePath.popFront())
        let newChildren: OrderedDictionary<String, FImmutableTree>
        if newChild.isEmpty() {
            var n = children
            children.removeValue(forKey: front)
            n.sort()
            newChildren = n
        } else {
            // TODO: Replace with SortedDictionary and just do an insert here!
            var n = children
            n[front] = newChild
            n.sort()
            newChildren = n
        }
        if value == nil && newChildren.isEmpty {
            return .empty()
        } else {
            return FImmutableTree(value: value, children: newChildren)
        }
    }

    @objc public func value(atPath relativePath: FPath) -> Any? {
        guard let front = relativePath.getFront() else {
            return value
        }

        guard let child = children[front] else {
            return nil
        }
        return child.value(atPath: relativePath.popFront())
    }

    @objc public func setTree(
        _ newTree: FImmutableTree,
        atPath relativePath: FPath
    ) -> FImmutableTree {
        guard let front = relativePath.getFront() else {
            return newTree
        }

        let child = children[front] ?? .empty()
        let newChild = child.setTree(newTree, atPath: relativePath.popFront())
        let newChildren: OrderedDictionary<String, FImmutableTree>
        if newChild.isEmpty() {
            var n = children
            n.removeValue(forKey: front)
            n.sort()
            newChildren = n
        } else {
            var n = children
            n[front] = newChild
            n.sort()
            newChildren = n
        }
        return FImmutableTree(value: value, children: newChildren)
    }

    @objc public func getChild(key: String) -> FImmutableTree? {
        children[key]
    }

    @objc public func fold(withBlock block: @escaping (_ path: FPath, _ value: Any?, _ foldedChildren: [String : Any]) -> Any) -> Any {
        fold(withPathSoFar: .empty(), withBlock: block)
    }

    @objc public func fold(
        withPathSoFar pathSoFar: FPath,
        withBlock block: @escaping (_ path: FPath, _ value: Any?, _ foldedChildren: [String : Any]) -> Any
    ) -> Any {
        var accum: [String: Any] = [:]
        for (childKey, childTree) in children {
            accum[childKey] = childTree.fold(withPathSoFar: pathSoFar.child(fromString: childKey), withBlock: block)
        }
        return block(pathSoFar, self.value, accum)

    }

    @objc public func find(
        onPath path: FPath,
        andApplyBlock block: @escaping (_ path: FPath, _ value: Any) -> Any?
    ) -> Any? {
        find(onPath: path, pathSoFar: .empty(), andApplyBlock: block)
    }

    @objc public func find(
        onPath pathToFollow: FPath,
        pathSoFar: FPath,
        andApplyBlock block: @escaping (_ path: FPath, _ value: Any?) -> Any?
    ) -> Any? {
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

    @objc public func forEachOn(
        path: FPath,
        whileBlock block: @escaping (_ path: FPath, _ value: Any) -> Bool
    ) -> FPath {
        forEachOn(path, pathSoFar: .empty(), whileBlock: block)
    }

    func forEachOn(
        _ pathToFollow: FPath,
        pathSoFar: FPath,
        whileBlock block: @escaping (FPath, Any) -> Bool
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

    @objc public func forEachOn(
        _ path: FPath,
        performBlock block: @escaping (_ path: FPath, _ value: Any) -> Void
    ) -> FImmutableTree {
        forEachOn(path, pathSoFar: .empty(), performBlock: block)
    }

    func forEachOn(
        _ pathToFollow: FPath,
        pathSoFar: FPath,
        performBlock block: @escaping (_ path: FPath, _ value: Any?) -> Void
    ) -> FImmutableTree {
        guard let front = pathToFollow.getFront() else {
            return self
        }
        if let value = value {
            block(pathSoFar, value)
        }
        guard let nextChild = children[front] else {
            return .empty()
        }
        return nextChild.forEachOn(pathToFollow.popFront(), pathSoFar: pathSoFar.child(fromString: front), performBlock: block)
    }

    @objc public func forEach(_ block: @escaping (_ path: FPath, _ value: Any) -> Void) {
        forEachPathSoFar(.empty(), withBlock: block)
    }

    func forEachPathSoFar(
        _ pathSoFar: FPath,
        withBlock block: @escaping (_ path: FPath, _ value: Any) -> Void
    ) {
        for (childKey, childTree) in children {
            childTree.forEachPathSoFar(pathSoFar.child(fromString: childKey), withBlock: block)
        }
        if let value = value {
            block(pathSoFar, value)
        }
    }

    @objc public func forEachChild(_ block: @escaping (_ childKey: String, _ childValue: Any?) -> Void) {
        for (childKey, childTree) in children {
            block(childKey, childTree.value)
        }
    }

    @objc public func forEachChildTree(_ block: @escaping (_ childKey: String, _ childTree: FImmutableTree) -> Void) {
        for (childKey, childTree) in children {
            block(childKey, childTree)
        }
    }


    @objc public override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? FImmutableTree else {
            return false
        }
        // XXX TODO, THIS MAY BE WRONG
        if let objcValue = value as? NSObject, let otherObjcValue = value as? NSObject {
            return objcValue.isEqual(otherObjcValue) && children == other.children
        }
        return children == other.children
    }
//
//    public override var hash: Int {
//      return self.children.hash * 31 + [self.value hash];

//    }
    public override var description: String {
        var string = "FImmutableTree { value=\(value.map { "\($0)" } ?? "<nil>")"
        string += ", children={"
        for (childKey, childTree) in children {
            let childTreeValue = childTree.value.map { "\($0)" } ?? "<nil>"
            string += " \(childKey)=\(childTreeValue)"
        }
        string += " } }"
        return string
    }

    public override var debugDescription: String {
        self.description
    }
}

internal class FImmutableTreeSwift<Element> {
    internal private(set) var value: Element?
    // TODO: Replace with SortedDictionary when it's fully baked.
    // This serves as an implementation placeholder for now.
    internal var children: OrderedDictionary<String, FImmutableTreeSwift<Element>>

    internal init(value: Element?) {
        self.value = value
        self.children = [:]
    }

    internal init(value: Element?, children: OrderedDictionary<String, FImmutableTreeSwift<Element>>) {
        self.value = value
        self.children = children
    }
//    @objc public init(
//        value aValue: Any,
//        children childrenMap: FImmutableSortedDictionary
//    ) {
//    }

    internal class func empty() -> FImmutableTreeSwift<Element> {
        FImmutableTreeSwift(value: nil)
    }

    internal func isEmpty() -> Bool {
        value == nil && children.isEmpty
    }

    internal func childrenIsEmpty() -> Bool {
        children.isEmpty
    }

    internal func findRootMost(
        matchingPath relativePath: FPath,
        predicate: @escaping (Element) -> Bool
    ) -> (path: FPath, value: Element)? {
        if let value = value, predicate(value) {
            return (path: .empty(), value: value)
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

    func subtree(atPath relativePath: FPath) -> FImmutableTreeSwift<Element> {
        guard let front = relativePath.getFront() else {
            return self
        }
        guard let childTree = children[front] else {
            return FImmutableTreeSwift.empty()
        }
        return childTree.subtree(atPath: relativePath.popFront())
    }

    func setValue(_ newValue: Element?, atPath relativePath: FPath) -> FImmutableTreeSwift<Element> {
        guard let front = relativePath.getFront() else {
            return FImmutableTreeSwift(value: newValue, children: children)
        }
        let child = children[front] ?? .empty()
        let newChild = child.setValue(newValue, atPath: relativePath.popFront())
        var newChildren = children

        // TODO: Replace with SortedDictionary and just do an insert here!
        newChildren[front] = newChild
        newChildren.sort()
        return FImmutableTreeSwift(value: self.value, children: newChildren)
    }

    func removeValue(atPath relativePath: FPath) -> FImmutableTreeSwift<Element> {
        guard let front = relativePath.getFront() else {
            if children.isEmpty {
                return .empty()
            } else {
                return FImmutableTreeSwift<Element>(value: nil, children: children)
            }
        }
        guard let child = children[front] else {
            return self
        }
        let newChild = child.removeValue(atPath: relativePath.popFront())
        let newChildren: OrderedDictionary<String, FImmutableTreeSwift<Element>>
        if newChild.isEmpty() {
            var n = children
            children.removeValue(forKey: front)
            n.sort()
            newChildren = n
        } else {
            // TODO: Replace with SortedDictionary and just do an insert here!
            var n = children
            n[front] = newChild
            n.sort()
            newChildren = n
        }
        if value == nil && newChildren.isEmpty {
            return .empty()
        } else {
            return FImmutableTreeSwift<Element>(value: value, children: newChildren)
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
        _ newTree: FImmutableTreeSwift<Element>,
        atPath relativePath: FPath
    ) -> FImmutableTreeSwift<Element> {
        guard let front = relativePath.getFront() else {
            return newTree
        }

        let child = children[front] ?? .empty()
        let newChild = child.setTree(newTree, atPath: relativePath.popFront())
        let newChildren: OrderedDictionary<String, FImmutableTreeSwift<Element>>
        if newChild.isEmpty() {
            var n = children
            n.removeValue(forKey: front)
            n.sort()
            newChildren = n
        } else {
            var n = children
            n[front] = newChild
            n.sort()
            newChildren = n
        }
        return FImmutableTreeSwift<Element>(value: value, children: newChildren)
    }

    func getChild(key: String) -> FImmutableTreeSwift<Element>? {
        children[key]
    }

    func fold<T>(withBlock block: @escaping (_ path: FPath, _ value: Element?, _ foldedChildren: [String : T]) -> T) -> T {
        fold(withPathSoFar: .empty(), withBlock: block)
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
        find(onPath: path, pathSoFar: .empty(), andApplyBlock: block)
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
        forEachOn(path, pathSoFar: .empty(), whileBlock: block)
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
    ) -> FImmutableTreeSwift<Element> {
        forEachOn(path, pathSoFar: .empty(), performBlock: block)
    }

    func forEachOn(
        _ pathToFollow: FPath,
        pathSoFar: FPath,
        performBlock block: @escaping (_ path: FPath, _ value: Element) -> Void
    ) -> FImmutableTreeSwift<Element> {
        guard let front = pathToFollow.getFront() else {
            return self
        }
        if let value = value {
            block(pathSoFar, value)
        }
        guard let nextChild = children[front] else {
            return .empty()
        }
        return nextChild.forEachOn(pathToFollow.popFront(), pathSoFar: pathSoFar.child(fromString: front), performBlock: block)
    }

    func forEach(_ block: @escaping (_ path: FPath, _ value: Element) -> Void) {
        forEachPathSoFar(.empty(), withBlock: block)
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

    func forEachChildTree(_ block: @escaping (_ childKey: String, _ childTree: FImmutableTreeSwift<Element>) -> Void) {
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
