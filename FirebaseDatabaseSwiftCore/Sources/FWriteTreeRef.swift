//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 19/02/2022.
//

import Foundation

/**
 * A FWriteTreeRef wraps a FWriteTree and a FPath, for convenient access to a
 * particular subtree. All the methods just proxy to the underlying FWriteTree.
 */
@objc public class FWriteTreeRef: NSObject {
    /**
     * The path to this particular FWriteTreeRef. Used for calling methods on
     * writeTree while exposing a simpler interface to callers.
     */
   let path: FPath
    /**
     * A reference to the actual tree of the write data. All methods are
     * pass-through to the tree, but with the appropriate path prefixed.
     *
     * This lets us make cheap references to points in the tree for sync points
     * without having to copy and maintain all of the data.
     */
    let writeTree: FWriteTree
    init(path: FPath, writeTree: FWriteTree) {
        self.path = path
        self.writeTree = writeTree
    }

    /**
     * @return If possible, returns a complete event cache, using the underlying
     * server data if possible. In addition, can be used to get a cache that
     * includes hidden writes, and excludes arbitrary writes. Note that customizing
     * the returned node can lead to a more expensive calculation.
     */
    @objc public func calculateCompleteEventCache(completeServerCache: FNode?) -> FNode? {
        writeTree.calculateCompleteEventCacheAtPath(
            path,
            completeServerCache: completeServerCache,
            excludeWriteIds: nil,
            includeHiddenWrites: false
        )
    }

    /**
     * @return If possible, returns a children node containing all of the complete
     * children we have data for. The returned data is a mix of the given server
     * data and write data.
     */
    @objc public func calculateCompleteEventChildren(completeServerChildren: FNode?) -> FNode {
        writeTree.calculateCompleteEventChildrenAtPath(path,
                          completeServerChildren:completeServerChildren)
    }

    /**
     * Given that either the underlying server data has updated or the outstanding
     * writes have been updating, determine what, if anything, needs to be applied
     * to the event cache.
     *
     * Possibilities:
     *
     * 1. No writes are shadowing. Events should be raised, the snap to be applied
     * comes from the server data.
     *
     * 2. Some writes are completly shadowing. No events to be raised.
     *
     * 3. Is partially shadowed. Events should be raised.
     *
     * Either existingEventSnap or existingServerSnap must exist, this is validated
     * via an assert.
     */
    @objc public func calculateEventCacheAfterServerOverwrite(childPath: FPath, existingEventSnap: FNode?, existingServerSnap: FNode) -> FNode? {
        writeTree.calculateEventCacheAfterServerOverwriteAtPath(
            path,
            childPath: childPath,
            existingEventSnap: existingEventSnap,
            existingServerSnap: existingServerSnap
        )
    }

    /**
     * Returns a node if there is a complete overwrite for this path. More
     * specifically, if there is a write at a higher path, this will return the
     * child of that write relative to the write and this path. Returns nil if there
     * is no write at this path.
     */
    @objc public func shadowingWriteAtPath(_ path: FPath) -> FNode? {
        writeTree.shadowingWriteAtPath(path.child(path))
    }

    /**
     * This method is used when processing child remove events on a query. If we
     * can, we pull in children that are outside the window, but may now be in the
     * window.
     */
    @objc public func calculateNextNodeAfterPost(_ post: FNamedNode,
                                    completeServerData: FNode?,
                                    reverse: Bool,
                                    index: FIndex) -> FNamedNode? {
        writeTree.calculateNextNodeAfterPost(post, atPath: path, completeServerData: completeServerData, reverse: reverse, index: index)
    }

    /**
     * Returns a complete child for a given server snap after applying all user
     * writes or nil if there is no complete child for this child key.
     */
    @objc public func calculateCompleteChild(_ childKey: String,
                                cache existingServerCache: FCacheNode) -> FNode? {
        writeTree.calculateCompleteChildAtPath(path, childKey: childKey, cache: existingServerCache)
    }

    /**
     * @return a WriteTreeref for a child.
     */
    @objc public func childWriteTreeRef(_ childKey: String) -> FWriteTreeRef {
        FWriteTreeRef(path: path.child(fromString: childKey), writeTree: writeTree)
    }
}
