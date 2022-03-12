//
//  File.swift
//  File
//
//  Created by Morten Bek Ditlevsen on 21/09/2021.
//

import Foundation

let prunePredicate: (Any?) -> (Bool) = { ($0 as? Bool) ?? false }
let keepPredicate: (Any?) -> (Bool) = { !(($0 as? Bool) ?? false) }

// TODO: When more is swiftified, FImmutableTree really, really ought to be generic
@objc public class FPruneForest: NSObject {
    static var pruneTree = FImmutableTree(value: true)
    static var keepTree = FImmutableTree(value: false)
    static var pruneForest = FPruneForest(forest: pruneTree)
    static var keepForest = FPruneForest(forest: keepTree)

    @objc public let pruneForest: FImmutableTree
    init(forest: FImmutableTree) {
        self.pruneForest = forest
    }
    @objc public class func empty() -> FPruneForest {
        FPruneForest(forest: .empty())
    }

    @objc public func prunesAnything() -> Bool {
        pruneForest.containsValue { value in
            (value as? Bool) ?? false
        }
    }

    @objc public func shouldPruneUnkeptDescendants(atPath path: FPath) -> Bool {
        let value = pruneForest.leafMostValue(onPath: path) as? Bool
        return value ?? false
    }

    @objc public func shouldKeepPath(_ path: FPath) -> Bool {
        let value = pruneForest.leafMostValue(onPath: path) as? Bool
        return value.map(!) ?? false
    }

    @objc public func affectsPath(_ path: FPath) -> Bool {
        print(pruneForest)
        return pruneForest.rootMostValue(onPath: path) != nil ||
        !pruneForest.subtree(atPath: path).isEmpty()
    }

    @objc public func child(_ childKey: String) -> FPruneForest {
        guard var childPruneForest = pruneForest.children[childKey] else {
            if let value = pruneForest.value {
                let boolValue = (value as? Bool) ?? false
                return boolValue ? .pruneForest : .keepForest
            } else {
                return .empty()
            }
        }
        if childPruneForest.value == nil && pruneForest.value != nil {
            childPruneForest = childPruneForest.setValue(pruneForest.value, atPath: .empty())
        }
        return FPruneForest(forest: childPruneForest)
    }

    @objc public func child(atPath path: FPath) -> FPruneForest {
        guard let front = path.getFront() else {
            return self
        }
        return child(front).child(atPath: path.popFront())
    }

    @objc public func prunePath(_ path: FPath) -> FPruneForest {
        if self.pruneForest.rootMostValue(onPath: path, matching: keepPredicate) != nil {
            //            [NSException raise:NSInvalidArgumentException
            //                        format:@"Can't prune path that was kept previously!"];
            fatalError("Can't prune path that was kept previously!")
        }
        if self.pruneForest.rootMostValue(onPath: path, matching: prunePredicate) != nil {
            // This path will already be pruned
            return self
        } else {
            // TODO: Clumsy - fix
            return FPruneForest(forest: pruneForest.setTree(FPruneForest.pruneTree, atPath: path))
        }
    }

    @objc public func keepPath(_ path: FPath) -> FPruneForest {
        if pruneForest.rootMostValue(onPath: path, matching: keepPredicate) != nil {
            // This path will already be kept
            return self
        } else {
            return FPruneForest(forest: pruneForest.setTree(FPruneForest.keepTree, atPath: path))
        }
    }

    @objc public func keepAll(_ children: Set<String>, atPath path: FPath) -> FPruneForest {
        if pruneForest.rootMostValue(onPath: path, matching: keepPredicate) != nil {
            // This path will already be kept
            return self
        } else {
            return self.setPruneValue(FPruneForest.keepTree, forAll: children, at: path)
        }
    }

    @objc public func pruneAll(_ children: Set<String>, atPath path: FPath) -> FPruneForest {
        if self.pruneForest.rootMostValue(onPath: path, matching: keepPredicate) != nil {
            //            [NSException raise:NSInvalidArgumentException
            //                        format:@"Can't prune path that was kept previously!"];
            fatalError("Can't prune path that was kept previously!")
        }

        if pruneForest.rootMostValue(onPath: path, matching:prunePredicate) != nil {
            // This path will already be pruned
            return self
        } else {
            return self.setPruneValue(FPruneForest.pruneTree, forAll: children, at: path)
        }
    }

    private func setPruneValue(
        _ pruneValue: FImmutableTree,
        forAll children: Set<String>,
        at path: FPath
    ) -> FPruneForest {
        let subtree = self.pruneForest.subtree(atPath: path)
        var childrenDictionary = subtree.children
        for childKey in children {
            childrenDictionary[childKey] = pruneValue
        }
        // XXX TODO - replace when using a SortedDictionary
        childrenDictionary.sort()
        let newSubtree = FImmutableTree(value: subtree.value, children: childrenDictionary)
        return FPruneForest(forest: self.pruneForest.setTree(newSubtree, atPath: path))
    }

    @objc public func enumarateKeptNodes(usingBlock block: @escaping (_ path: FPath) -> Void) {
        pruneForest.forEach { path, value in
            if !(value as? Bool ?? false) {
                block(path)
            }
        }
    }
}
