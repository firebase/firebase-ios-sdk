//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 09/03/2022.
//

import Foundation

@objc public class FNoCompleteChildSource: NSObject, FCompleteChildSource {
    @objc public static var instance: FNoCompleteChildSource = .init()
    public func completeChild(_ childKey: String) -> FNode? {
        nil
    }
    public func childByIndex(_ index: FIndex, afterChild child: FNamedNode, isReverse: Bool) -> FNamedNode? {
        nil
    }
}

/**
 * An implementation of FCompleteChildSource that uses a FWriteTree in addition
 * to any other server data or old event caches available to calculate complete
 * children.
 */
@objc public class FWriteTreeCompleteChildSource: NSObject, FCompleteChildSource {
    @objc public let writes: FWriteTreeRef
    @objc public let viewCache: FViewCache
    @objc public let completeServerCache: FNode?
    @objc public init(writes: FWriteTreeRef, viewCache: FViewCache, serverCache: FNode?) {
        self.writes = writes
        self.viewCache = viewCache
        self.completeServerCache = serverCache
    }
    public func completeChild(_ childKey: String) -> FNode? {
        let node = viewCache.cachedEventSnap
        if node.isComplete(forChild: childKey) {
            return node.node.getImmediateChild(childKey)
        } else {
            let serverNode: FCacheNode
            if let completeServerCache = completeServerCache {
                // Since we're only ever getting child nodes, we can use the key
                // index here
                let indexed = FIndexedNode(node: completeServerCache, index: FKeyIndex.keyIndex)
                serverNode = FCacheNode(indexedNode: indexed, isFullyInitialized: true, isFiltered: false)
            } else {
                serverNode = viewCache.cachedServerSnap
            }
            return writes.calculateCompleteChild(childKey, cache: serverNode)
        }
    }

    public func childByIndex(_ index: FIndex, afterChild child: FNamedNode, isReverse: Bool) -> FNamedNode? {
        let completeServerData = completeServerCache ?? viewCache.completeServerSnap
        return writes.calculateNextNodeAfterPost(child,
                                                 completeServerData: completeServerData,
                                                 reverse: isReverse,
                                                 index: index)
    }
}


@objc public class FViewProcessor: NSObject {
    public let filter: FNodeFilter
    public init(filter: FNodeFilter) {
        self.filter = filter
    }

    @objc public func applyOperationOn(_ oldViewCache: FViewCache,
                                       operation: FOperation,
                                       writesCache: FWriteTreeRef,
                                       completeCache: FNode?) -> FViewProcessorResult {
        let accumulator = FChildChangeAccumulator()
        let newViewCache: FViewCache

        switch operation.type {
        case .overwrite:
            // XXX TODO: TYPE SAFETIFY THIS
            let overwrite = operation as! FOverwrite
            if operation.source.fromUser {
                newViewCache = applyUserOverwriteTo(oldViewCache,
                                                    changePath: overwrite.path,
                                                    changedSnap: overwrite.snap,
                                                    writesCache: writesCache,
                                                    completeCache: completeCache,
                                                    accumulator: accumulator)
            } else {
                assert(operation.source.fromServer, "Unknown source for overwrite.")
                // We filter the node if it's a tagged update or the node has been
                // previously filtered  and the update is not at the root in which
                // case it is ok (and necessary) to mark the node unfiltered again
                let filterServerNode = overwrite.source.isTagged ||
                                        (oldViewCache.cachedServerSnap.isFiltered &&
                                         !overwrite.path.isEmpty)
                newViewCache = applyServerOverwriteTo(oldViewCache,
                                                      changePath: overwrite.path,
                                                      snap: overwrite.snap,
                                                      writesCache: writesCache,
                                                      completeCache: completeCache,
                                                      filterServerNode: filterServerNode,
                                                      accumulator: accumulator)
            }
        case .merge:
            let merge = operation as! FMerge
            if operation.source.fromUser {
                newViewCache = applyUserMergeTo(oldViewCache,
                                                path:merge.path,
                                     changedChildren:merge.children,
                                         writesCache:writesCache,
                                       completeCache:completeCache,
                                         accumulator:accumulator)
            } else {
                assert(operation.source.fromServer, "Unknown source for merge.")
                // We filter the node if it's a tagged update or the node has been
                // previously filtered
                let filterServerNode = merge.source.isTagged ||
                                        oldViewCache.cachedServerSnap.isFiltered
                newViewCache = applyServerMergeTo(oldViewCache,
                                                   path:merge.path,
                                        changedChildren:merge.children,
                                            writesCache:writesCache,
                                          completeCache:completeCache,
                                       filterServerNode:filterServerNode,
                                            accumulator:accumulator)

            }
        case .ackUserWrite:
            let ackWrite = operation as! FAckUserWrite
            if !ackWrite.revert {

                newViewCache = ackUserWriteOn(oldViewCache,
                                              ackPath:ackWrite.path,
                                              affectedTree:ackWrite.affectedTree,
                                              writesCache:writesCache,
                                              completeCache:completeCache,
                                              accumulator:accumulator)
            } else {
                newViewCache = revertUserWriteOn(oldViewCache,
                                                 path: ackWrite.path,
                                                 writesCache: writesCache,
                                                 completeCache: completeCache,
                                                 accumulator: accumulator)
            }
        case .listenComplete:
            newViewCache = listenCompleteOldCache(oldViewCache,
                                            path:operation.path,
                                     writesCache:writesCache,
                                     serverCache:completeCache,
                                     accumulator:accumulator)
        }
        let changes = maybeAddValueFromOldViewCache(oldViewCache, newViewCache: newViewCache, changes: accumulator.changes)
        let results = FViewProcessorResult(viewCache: newViewCache, changes: changes)
        return results
    }

    private func maybeAddValueFromOldViewCache(_ oldViewCache: FViewCache, newViewCache: FViewCache, changes: [FChange]) -> [FChange] {
        var newChanges = changes
        let eventSnap = newViewCache.cachedEventSnap
        if eventSnap.isFullyInitialized {
            let isLeafOrEmpty = eventSnap.node.isLeafNode() || eventSnap.node.isEmpty
            if !changes.isEmpty || !oldViewCache.cachedEventSnap.isFullyInitialized ||
                (isLeafOrEmpty && !eventSnap.node.isEqual(oldViewCache.completeEventSnap)) ||
                !eventSnap.node.getPriority().isEqual(oldViewCache.completeEventSnap?.getPriority()) {
                let valueChange = FChange(type: .value, indexedNode: eventSnap.indexedNode)
                newChanges.append(valueChange)
            }
        }
        return newChanges
    }

    private func generateEventCacheAfterServerEvent(_ viewCache: FViewCache, path changePath: FPath, writesCache: FWriteTreeRef, source: FCompleteChildSource, accumulator: FChildChangeAccumulator) -> FViewCache {
        let oldEventSnap = viewCache.cachedEventSnap
        guard writesCache.shadowingWriteAtPath(changePath) == nil else {
            // we have a shadowing write, ignore changes.
            return viewCache
        }

        let newEventCache: FIndexedNode
        if let childKey = changePath.getFront() {
            if childKey == ".priority" {
                assert(changePath.length() == 1, "Can't have a priority with additional path components")
                let oldEventNode = oldEventSnap.node
                let serverNode = viewCache.cachedServerSnap.node
                // we might have overwrites for this priority
                let updatedPriority = writesCache.calculateEventCacheAfterServerOverwrite(childPath: changePath, existingEventSnap: oldEventNode, existingServerSnap: serverNode)
                if let updatedPriority = updatedPriority {
                    newEventCache =
                    self.filter.updatePriority(updatedPriority,
                                               forNode:oldEventSnap.indexedNode)
                } else {
                    // priority didn't change, keep old node
                    newEventCache = oldEventSnap.indexedNode
                }

            } else {
                let childChangePath = changePath.popFront()
                let newEventChild: FNode?
                if oldEventSnap.isComplete(forChild: childKey) {
                    let serverNode = viewCache.cachedServerSnap.node;
                    let eventChildUpdate = writesCache.calculateEventCacheAfterServerOverwrite(childPath: changePath, existingEventSnap: oldEventSnap.node, existingServerSnap: serverNode)
                    if let eventChildUpdate = eventChildUpdate {
                        newEventChild =
                        oldEventSnap.node.getImmediateChild(childKey).updateChild(childChangePath, withNewChild: eventChildUpdate)
                    } else {
                        // Nothing changed, just keep the old child
                        newEventChild =
                        oldEventSnap.node.getImmediateChild(childKey)
                    }
                } else {
                    newEventChild = writesCache.calculateCompleteChild(childKey,                                              cache:viewCache.cachedServerSnap)
                }
                if let newEventChild = newEventChild {
                    newEventCache =
                    self.filter.updateChildIn(oldEventSnap.indexedNode,
                                              forChildKey: childKey,
                                              newChild: newEventChild,
                                              affectedPath: childChangePath,
                                              fromSource: source,
                                              accumulator: accumulator)
                } else {
                    // No complete children available or no change
                    newEventCache = oldEventSnap.indexedNode
                }
            }
        } else {
            // changePath is empty
            // TODO: figure out how this plays with "sliding ack windows"
            assert(
                viewCache.cachedServerSnap.isFullyInitialized,
                "If change path is empty, we must have complete server data")
            let nodeWithLocalWrites: FNode
            if viewCache.cachedServerSnap.isFiltered {
                // We need to special case this, because we need to only apply
                // writes to complete children, or we might end up raising
                // events for incomplete children. If the server data is
                // filtered deep writes cannot be guaranteed to be complete
                let serverCache = viewCache.completeServerSnap
                let completeChildren = (serverCache as? FChildrenNode) ?? FEmptyNode.emptyNode
                nodeWithLocalWrites = writesCache.calculateCompleteEventChildren(completeServerChildren: completeChildren)
            } else {

                /// XXX TODO: FORCE UNWRAP MAY HIDE A BUG
                nodeWithLocalWrites = writesCache.calculateCompleteEventCache(completeServerCache: viewCache.completeServerSnap)!
            }
            let indexedNode = FIndexedNode(node: nodeWithLocalWrites, index: filter.index)
            newEventCache = filter.updateFullNode(viewCache.cachedEventSnap.indexedNode, withNewNode: indexedNode, accumulator: accumulator)
        }

        return viewCache.updateEventSnap(newEventCache,
                                         isComplete:(oldEventSnap.isFullyInitialized ||
                                                     changePath.isEmpty),
                                         isFiltered:self.filter.filtersNodes)
    }

    private func applyServerOverwriteTo(_ oldViewCache: FViewCache,
                                        changePath: FPath,
                                        snap changedSnap: FNode,
                                        writesCache: FWriteTreeRef,
                                        completeCache: FNode?,
                                        filterServerNode: Bool,
                                        accumulator: FChildChangeAccumulator) -> FViewCache {
        let oldServerSnap = oldViewCache.cachedServerSnap
        let newServerCache: FIndexedNode
        let serverFilter = filterServerNode ? self.filter : self.filter.indexedFilter
        if let childKey = changePath.getFront() {
            if serverFilter.filtersNodes && !oldServerSnap.isFiltered {
                let updatePath = changePath.popFront()
                let newChild = oldServerSnap.node.getImmediateChild(childKey)
                    .updateChild(updatePath, withNewChild: changedSnap)
                let indexed = oldServerSnap.indexedNode.updateChild(childKey, withNewChild: newChild)
                newServerCache = serverFilter.updateFullNode(oldServerSnap.indexedNode,
                                                             withNewNode: indexed,
                                                             accumulator: nil)
            } else {
                if !oldServerSnap.isComplete(forPath: changePath) && changePath.length() > 1 {
                    // We don't update incomplete nodes with updates intended for other
                    // listeners.
                    return oldViewCache
                }
                let childChangePath = changePath.popFront()
                let childNode = oldServerSnap.node.getImmediateChild(childKey)
                let newChildNode = childNode.updateChild(childChangePath, withNewChild: changedSnap)
                if childKey == ".priority" {
                    newServerCache = serverFilter.updatePriority(newChildNode, forNode: oldServerSnap.indexedNode)
                } else {
                    newServerCache = serverFilter.updateChildIn(oldServerSnap.indexedNode, forChildKey: childKey, newChild: newChildNode, affectedPath: childChangePath, fromSource: FNoCompleteChildSource.instance, accumulator: nil)
                }
            }
        } else {
            let indexed = FIndexedNode(node: changedSnap, index: serverFilter.index)
            newServerCache = serverFilter.updateFullNode(oldServerSnap.indexedNode, withNewNode: indexed, accumulator: nil)
        }
        let newViewCache = oldViewCache.updateServerSnap(newServerCache,
                                                         isComplete: oldServerSnap.isFullyInitialized || changePath.isEmpty,
                                                         isFiltered: serverFilter.filtersNodes)
        let source = FWriteTreeCompleteChildSource(writes: writesCache,
                                                   viewCache: newViewCache,
                                                   serverCache: completeCache)
        return generateEventCacheAfterServerEvent(newViewCache,
                                                  path: changePath,
                                                  writesCache: writesCache,
                                                  source: source,
                                                  accumulator: accumulator)
    }

    private func applyUserOverwriteTo(_ oldViewCache: FViewCache,
                                      changePath: FPath,
                                      changedSnap: FNode,
                                      writesCache: FWriteTreeRef,
                                      completeCache: FNode?,
                                      accumulator: FChildChangeAccumulator) -> FViewCache {
        let oldEventSnap = oldViewCache.cachedEventSnap
        let newViewCache: FViewCache
        let source = FWriteTreeCompleteChildSource(writes: writesCache,
                                                   viewCache: oldViewCache,
                                                   serverCache: completeCache)
        if let childKey = changePath.getFront() {
            if childKey == ".priority" {
                let newEventCache = filter.updatePriority(changedSnap,
                                                          forNode: oldViewCache.cachedEventSnap.indexedNode)
                newViewCache = oldViewCache.updateEventSnap(newEventCache,
                                                            isComplete: oldEventSnap.isFullyInitialized,
                                                            isFiltered: oldEventSnap.isFiltered)
            } else {
                let childChangePath = changePath.popFront()
                let oldChild = oldEventSnap.node.getImmediateChild(childKey)
                let newChild: FNode
                if let parent = childChangePath.parent() {
                    if let childNode = source.completeChild(childKey) {
                        if childChangePath.getBack() == ".priority" &&
                            childNode.getChild(parent).isEmpty {
                            // This is a priority update on an empty node. If this
                            // node exists on the server, the server will send down
                            // the priority in the update, so ignore for now
                            newChild = childNode
                        } else {
                            newChild = childNode.updateChild(childChangePath,
                                                             withNewChild:changedSnap)

                        }
                    } else {
                        newChild = FEmptyNode.emptyNode
                    }
                } else {
                    // Child overwrite, we can replace the child
                    newChild = changedSnap
                }
                if !oldChild.isEqual(newChild) {
                    let newEventSnap = filter.updateChildIn(oldEventSnap.indexedNode, forChildKey: childKey, newChild: newChild, affectedPath: childChangePath, fromSource: source, accumulator: accumulator)
                    newViewCache = oldViewCache.updateEventSnap(newEventSnap, isComplete: oldEventSnap.isFullyInitialized, isFiltered: filter.filtersNodes)
                } else {
                    newViewCache = oldViewCache
                }
            }
        } else {
            let newIndexed = FIndexedNode(node: changedSnap, index: filter.index)
            let newEventCache = filter.updateFullNode(oldEventSnap.indexedNode,
                                                      withNewNode: newIndexed,
                                                      accumulator: accumulator)
            newViewCache = oldViewCache.updateEventSnap(newEventCache,
                                                        isComplete: true,
                                                        isFiltered: filter.filtersNodes)
        }
        return newViewCache
    }

    private static func cache(_ viewCache: FViewCache, hasChild childKey: String) -> Bool {
        viewCache.cachedEventSnap.isComplete(forChild: childKey)
    }

    /**
     * @param changedChildren NSDictionary of child name (NSString*) to child value
     * (id<FNode>)
     */
    private func applyUserMergeTo(_ viewCache: FViewCache,
                                  path: FPath,
                                  changedChildren: FCompoundWrite,
                                  writesCache: FWriteTreeRef,
                                  completeCache serverCache: FNode?,
                                  accumulator: FChildChangeAccumulator) -> FViewCache {
        // HACK: In the case of a limit query, there may be some changes that bump
        // things out of the window leaving room for new items.  It's important we
        // process these changes first, so we iterate the changes twice, first
        // processing any that affect items currently in view.
        // TODO: I consider an item "in view" if cacheHasChild is true, which checks
        // both the server and event snap.  I'm not sure if this will result in edge
        // cases when a child is in one but not the other.
        var curViewCache = viewCache
        changedChildren.enumerateWrites { relativePath, childNode, stop in
            let writePath = path.child(relativePath)
            // Note: we know that getFront returns a value since enumerateWrites always
            // returns a non-empty path
            if FViewProcessor.cache(viewCache, hasChild: writePath.getFront()!) {
                curViewCache = self.applyUserOverwriteTo(curViewCache,
                                                         changePath: writePath,
                                                         changedSnap: childNode,
                                                         writesCache: writesCache,
                                                         completeCache: serverCache,
                                                         accumulator: accumulator)
            }
        }
        changedChildren.enumerateWrites { relativePath, childNode, stop in
            let writePath = path.child(relativePath)
            if !FViewProcessor.cache(viewCache, hasChild: writePath.getFront()!) {
                curViewCache = self.applyUserOverwriteTo(curViewCache,
                                                         changePath: writePath,
                                                         changedSnap: childNode,
                                                         writesCache: writesCache,
                                                         completeCache: serverCache,
                                                         accumulator: accumulator)
            }
        }
        return curViewCache
    }

    private func applyServerMergeTo(_ viewCache: FViewCache,
                                    path: FPath,
                                    changedChildren: FCompoundWrite,
                                    writesCache: FWriteTreeRef,
                                    completeCache serverCache: FNode?,
                                    filterServerNode: Bool,
                                    accumulator: FChildChangeAccumulator) -> FViewCache {
        // If we don't have a cache yet, this merge was intended for a previously
        // listen in the same location. Ignore it and wait for the complete data
        // update coming soon.
        if viewCache.cachedServerSnap.node.isEmpty &&
            !viewCache.cachedServerSnap.isFullyInitialized {
            return viewCache
        }
        // HACK: In the case of a limit query, there may be some changes that bump
        // things out of the window leaving room for new items.  It's important we
        // process these changes first, so we iterate the changes twice, first
        // processing any that affect items currently in view.
        // TODO: I consider an item "in view" if cacheHasChild is true, which checks
        // both the server and event snap.  I'm not sure if this will result in edge
        // cases when a child is in one but not the other.
        var curViewCache = viewCache
        let actualMerge: FCompoundWrite
        if path.isEmpty {
            actualMerge = changedChildren
        } else {
            actualMerge = FCompoundWrite
                .emptyWrite
                .addCompoundWrite(changedChildren, atPath: path)
        }
        let serverNode = viewCache.cachedServerSnap.node
        let childCompoundWrites = actualMerge.childCompoundWrites
        for (childKey, childMerge) in childCompoundWrites {
            if serverNode.hasChild(childKey) {
                let serverChild = viewCache.cachedServerSnap.node.getImmediateChild(childKey)
                let newChild = childMerge.applyToNode(serverChild)
                curViewCache = applyServerOverwriteTo(curViewCache,
                                                      changePath: FPath(with: childKey),
                                                      snap: newChild,
                                                      writesCache: writesCache,
                                                      completeCache: serverCache,
                                                      filterServerNode: filterServerNode,
                                                      accumulator: accumulator)
            }
        }
        for (childKey, childMerge) in childCompoundWrites {
            let isUnknownDeepMerge = !viewCache.cachedServerSnap.isComplete(forChild: childKey) && childMerge.rootWrite == nil
            if !serverNode.hasChild(childKey) && !isUnknownDeepMerge {
                let serverChild = viewCache.cachedServerSnap.node.getImmediateChild(childKey)
                let newChild = childMerge.applyToNode(serverChild)
                curViewCache = applyServerOverwriteTo(curViewCache,
                                                      changePath: FPath(with: childKey),
                                                      snap: newChild,
                                                      writesCache: writesCache,
                                                      completeCache: serverCache,
                                                      filterServerNode: filterServerNode,
                                                      accumulator: accumulator)
            }
        }
        return curViewCache
    }

    private func ackUserWriteOn(_ viewCache: FViewCache,
                                ackPath: FPath,
                                affectedTree: FImmutableTree<Bool>,
                                writesCache: FWriteTreeRef,
                                completeCache: FNode?,
                                accumulator: FChildChangeAccumulator) -> FViewCache {
        guard writesCache.shadowingWriteAtPath(ackPath) == nil else {
            return viewCache
        }
        // Only filter server node if it is currently filtered
        let filterServerNode = viewCache.cachedServerSnap.isFiltered

        // Essentially we'll just get our existing server cache for the affected
        // paths and re-apply it as a server update now that it won't be shadowed.

        let serverCache = viewCache.cachedServerSnap
        if affectedTree.value != nil {
            // This is an overwrite.
            if (ackPath.isEmpty && serverCache.isFullyInitialized) || serverCache.isComplete(forPath: ackPath) {
                return applyServerOverwriteTo(viewCache,
                                              changePath: ackPath,
                                              snap: serverCache.node.getChild(ackPath),
                                              writesCache: writesCache,
                                              completeCache: completeCache,
                                              filterServerNode: filterServerNode,
                                              accumulator: accumulator)
            } else if ackPath.isEmpty {
                // This is a goofy edge case where we are acking data at this
                // location but don't have full data.  We should just re-apply
                // whatever we have in our cache as a merge.
                var changedChildren = FCompoundWrite.emptyWrite
                // TODO: Make more better than casting
                if let childrenNode = serverCache.node as? FChildrenNode {
                    for (name, node) in childrenNode.children {
                        changedChildren = changedChildren.addWrite(node,
                                                                   atKey: name.key)
                    }
                }
                return applyServerMergeTo(viewCache,
                                           path:ackPath,
                                changedChildren:changedChildren,
                                    writesCache:writesCache,
                                  completeCache:completeCache,
                               filterServerNode:filterServerNode,
                                    accumulator:accumulator)

            } else {
                return viewCache
            }
        } else {
            // This is a merge.
            var changedChildren = FCompoundWrite.emptyWrite
            affectedTree.forEach { mergePath, value in
                let serverCachePath = ackPath.child(mergePath)
                if serverCache.isComplete(forPath: serverCachePath) {
                    changedChildren = changedChildren.addWrite(serverCache.node.getChild(serverCachePath),
                                                               atPath:mergePath)
                }

            }
            return applyServerMergeTo(viewCache,
                                      path: ackPath,
                                      changedChildren: changedChildren,
                                      writesCache: writesCache,
                                      completeCache: completeCache,
                                      filterServerNode: filterServerNode,
                                      accumulator: accumulator)

        }

    }

    private func revertUserWriteOn(_ viewCache: FViewCache, path: FPath, writesCache: FWriteTreeRef, completeCache: FNode?, accumulator: FChildChangeAccumulator) -> FViewCache {

        guard writesCache.shadowingWriteAtPath(path) == nil else {
            return viewCache
        }
        let source = FWriteTreeCompleteChildSource(writes: writesCache,
                                                   viewCache: viewCache,
                                                   serverCache: completeCache)
        let oldEventCache = viewCache.cachedEventSnap.indexedNode
        var newEventCache: FIndexedNode
        if path.isEmpty || path.getFront() == ".priority" {
            let newNode: FNode
            if viewCache.cachedServerSnap.isFullyInitialized {
                // XXX TODO: THIS FORCE UNWRAP MIGHT ACTUALLY BE A HIDDEN BUG!
                newNode = writesCache.calculateCompleteEventCache(completeServerCache: viewCache.completeServerSnap)!
            } else {
                newNode = writesCache.calculateCompleteEventChildren(completeServerChildren: viewCache.cachedServerSnap.node)
            }
            let indexedNode = FIndexedNode(node: newNode, index: filter.index)
            newEventCache = filter.updateFullNode(oldEventCache, withNewNode: indexedNode, accumulator: accumulator)
        } else {
            // TODO: This is safe (see if-else), but it could be compiler-proven rather than force unwrapped
            let childKey = path.getFront()!
            var newChild = writesCache.calculateCompleteChild(childKey, cache: viewCache.cachedServerSnap)
            if newChild == nil && viewCache.cachedServerSnap.isComplete(forChild: childKey) {
                newChild = oldEventCache.node.getImmediateChild(childKey)
            }
            if let newChild = newChild {
                newEventCache = filter.updateChildIn(oldEventCache,
                                                     forChildKey: childKey, newChild: newChild, affectedPath: path.popFront(), fromSource: source, accumulator: accumulator)
            } else if viewCache.cachedEventSnap.node.hasChild(childKey) {
                // No complete child available, delete the existing one, if any
                newEventCache =
                filter.updateChildIn(oldEventCache,
                                     forChildKey:childKey,
                                     newChild:FEmptyNode.emptyNode,
                                     affectedPath:path.popFront(),
                                     fromSource:source,
                                     accumulator:accumulator)

            } else {
                newEventCache = oldEventCache
            }
            if newEventCache.node.isEmpty && viewCache.cachedServerSnap.isFullyInitialized {
                // We might have reverted all child writes. Maybe the old event
                // was a leaf node.
                if let complete = writesCache.calculateCompleteEventCache(completeServerCache: viewCache.completeServerSnap), complete.isLeafNode() {
                    let indexed = FIndexedNode(node: complete)
                    newEventCache = filter.updateFullNode(newEventCache, withNewNode: indexed, accumulator: accumulator)
                }
            }
        }
        let complete = viewCache.cachedServerSnap.isFullyInitialized || writesCache.shadowingWriteAtPath(.empty) != nil
        return viewCache.updateEventSnap(newEventCache, isComplete: complete, isFiltered: filter.filtersNodes)

    }

    private func listenCompleteOldCache(_ viewCache: FViewCache,
                                        path: FPath,
                                        writesCache: FWriteTreeRef,
                                        serverCache: FNode?,
                                        accumulator: FChildChangeAccumulator) -> FViewCache {
        let oldServerNode = viewCache.cachedServerSnap
        let newViewCache = viewCache.updateServerSnap(oldServerNode.indexedNode, isComplete: oldServerNode.isFullyInitialized || path.isEmpty, isFiltered: oldServerNode.isFiltered)
        return generateEventCacheAfterServerEvent(newViewCache, path: path, writesCache: writesCache, source: FNoCompleteChildSource.instance, accumulator: accumulator)
    }
}
