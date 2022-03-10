//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 09/03/2022.
//

import Foundation

@objc public class FNoCompleteChildSource: NSObject, FCompleteChildSource {
    @objc public static var instance: FNoCompleteChildSource = .init()
    public func completeChild(_ childKey: String) -> FNode {
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
/*

 */


@objc public class FViewProcessor: NSObject {
    @objc public let filter: FNodeFilter
    @objc public init(filter: FNodeFilter) {
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
                newViewCache = applyUserOverwriteTo(oldViewCache, changePath: overwrite.path, changedSnap: overwrite.snap, writesCache: writesCache, completeCache, completeCache, accumulator: accumulator)
            } else {
                assert(operation.source.fromServer, "Unknown source for overwrite.")
                // We filter the node if it's a tagged update or the node has been
                // previously filtered  and the update is not at the root in which
                // case it is ok (and necessary) to mark the node unfiltered again
                let filterServerNode = overwrite.source.isTagged ||
                                        (oldViewCache.cachedServerSnap.isFiltered &&
                                         !overwrite.path.isEmpty())
                newViewCache = applyServerOverwriteTo(oldViewCache,
                                                 changePath:overwrite.path,
                                                       snap:overwrite.snap,
                                                writesCache:writesCache,
                                              completeCache:completeCache,
                                           filterServerNode:filterServerNode,
                                                accumulator:accumulator)
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
                (isLeafOrEmpty && !eventSnap.node.isEqual(oldViewCache.completeServerSnap)) ||
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
                nodeWithLocalWrites = writesCache.calculateCompleteEventChildren(completeServerChildren:
                                                                                    viewCache.completeServerSnap)
            }
            let indexedNode = FIndexedNode(node: nodeWithLocalWrites, index: filter.index)
            newEventCache = filter.updateFullNode(viewCache.cachedEventSnap.indexedNode, withNewNode: indexedNode, accumulator: accumulator)
        }

        return viewCache.updateEventSnap(newEventCache,
                                         isComplete:(oldEventSnap.isFullyInitialized ||
                                                     changePath.isEmpty()),
                                         isFiltered:self.filter.filtersNodes)
    }
    /*

     */

    @objc public func revertUserWriteOn(_ viewCache: FViewCache, path: FPath, writesCache: FWriteTreeRef, completeCache: FNode?, accumulator: FChildChangeAccumulator) -> FViewCache {

    }
}
/*

 */
