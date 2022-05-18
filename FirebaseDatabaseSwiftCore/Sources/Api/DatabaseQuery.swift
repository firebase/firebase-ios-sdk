//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 24/04/2022.
//

import Foundation

/**
 * A FIRDatabaseHandle is used to identify listeners of Firebase Database
 * events. These handles are returned by observeEventType: and can later be
 * passed to removeObserverWithHandle: to stop receiving updates.
 */
public typealias DatabaseHandle = Int

/**
 * A FIRDatabaseQuery instance represents a query over the data at a particular
 * location.
 *
 * You create one by calling one of the query methods (queryOrderedByChild:,
 * queryStartingAtValue:, etc.) on a FIRDatabaseReference. The query methods can
 * be chained to further specify the data you are interested in observing
 */
@objc(FIRDatabaseQuery) public class DatabaseQuery: NSObject {

    // MARK: - Attach observers to read data

    /**
     * observeEventType:withBlock: is used to listen for data changes at a
     * particular location. This is the primary way to read data from the Firebase
     * Database. Your block will be triggered for the initial data and again
     * whenever the data changes.
     *
     * Use removeObserverWithHandle: to stop receiving updates.
     *
     * @param eventType The type of event to listen for.
     * @param block The block that should be called with initial data and updates.
     * It is passed the data as a FIRDataSnapshot.
     * @return A handle used to unregister this block later using
     * removeObserverWithHandle:
     */
    @objc public func observeEventType(_ eventType: DataEventType,
                                       withBlock block: @escaping (DataSnapshot) -> Void) -> DatabaseHandle {
        FValidationSwift.validateFrom("observeEventType:withBlock:", knownEventType: eventType)
        return observeEventType(eventType, withBlock: block, withCancelBlock: nil)
    }
    /**
     * observeEventType:andPreviousSiblingKeyWithBlock: is used to listen for data
     * changes at a particular location. This is the primary way to read data from
     * the Firebase Database. Your block will be triggered for the initial data and
     * again whenever the data changes. In addition, for FIRDataEventTypeChildAdded,
     * FIRDataEventTypeChildMoved, and FIRDataEventTypeChildChanged events, your
     * block will be passed the key of the previous node by priority order.
     *
     * Use removeObserverWithHandle: to stop receiving updates.
     *
     * @param eventType The type of event to listen for.
     * @param block The block that should be called with initial data and updates.
     * It is passed the data as a FIRDataSnapshot and the previous child's key.
     * @return A handle used to unregister this block later using
     * removeObserverWithHandle:
     */
    @objc public func observeEventType(_ eventType: DataEventType,
                                       andPreviousSiblingKeyWithBlock block: @escaping (_ snapshot: DataSnapshot, _ prevKey: String?) -> Void) -> DatabaseHandle {
        FValidationSwift.validateFrom("observeEventType:andPreviousSiblingKeyWithBlock:", knownEventType: eventType)
        return observeEventType(eventType, andPreviousSiblingKeyWithBlock: block, withCancelBlock: nil)
    }

    /**
     * observeEventType:withBlock: is used to listen for data changes at a
     * particular location. This is the primary way to read data from the Firebase
     * Database. Your block will be triggered for the initial data and again
     * whenever the data changes.
     *
     * The cancelBlock will be called if you will no longer receive new events due
     * to no longer having permission.
     *
     * Use removeObserverWithHandle: to stop receiving updates.
     *
     * @param eventType The type of event to listen for.
     * @param block The block that should be called with initial data and updates.
     * It is passed the data as a FIRDataSnapshot.
     * @param cancelBlock The block that should be called if this client no longer
     * has permission to receive these events
     * @return A handle used to unregister this block later using
     * removeObserverWithHandle:
     */
    @objc public func observeEventType(_ eventType: DataEventType,
                                       withBlock block: @escaping (_ snapshot: DataSnapshot) -> Void,
                                       withCancelBlock cancelBlock: ((Error) -> Void)?) -> DatabaseHandle {
        FValidationSwift.validateFrom("observeEventType:withBlock:withCancelBlock:",
                                      knownEventType: eventType)
        if eventType == .value {
            // Handle FIRDataEventTypeValue specially because they shouldn't have
            // prevName callbacks
            let handle = FUtilitiesSwift.LUIDGenerator()
            observeValueEventWithHandle(handle, withBlock: block, cancelCallback: cancelBlock)
            return handle
        } else {
            // Wrap up the userCallback so we can treat everything as a callback
            // that has a prevName
            return observeEventType(
                eventType,
                andPreviousSiblingKeyWithBlock: { snapshot, _ in
                    block(snapshot)
                },
                withCancelBlock: cancelBlock)
        }
    }

    /**
     * observeEventType:andPreviousSiblingKeyWithBlock: is used to listen for data
     * changes at a particular location. This is the primary way to read data from
     * the Firebase Database. Your block will be triggered for the initial data and
     * again whenever the data changes. In addition, for FIRDataEventTypeChildAdded,
     * FIRDataEventTypeChildMoved, and FIRDataEventTypeChildChanged events, your
     * block will be passed the key of the previous node by priority order.
     *
     * The cancelBlock will be called if you will no longer receive new events due
     * to no longer having permission.
     *
     * Use removeObserverWithHandle: to stop receiving updates.
     *
     * @param eventType The type of event to listen for.
     * @param block The block that should be called with initial data and updates.
     * It is passed the data as a FIRDataSnapshot and the previous child's key.
     * @param cancelBlock The block that should be called if this client no longer
     * has permission to receive these events
     * @return A handle used to unregister this block later using
     * removeObserverWithHandle:
     */
    @objc public func observeEventType(_ eventType: DataEventType,
                                       andPreviousSiblingKeyWithBlock block: @escaping (_ snapshot: DataSnapshot, _ prevKey: String?) -> Void, withCancelBlock cancelBlock: ((Error) -> Void)?) -> DatabaseHandle {
        FValidationSwift.validateFrom("observeEventType:andPreviousSiblingKeyWithBlock:withCancelBlock:", knownEventType: eventType)
        if eventType == .value {
            // TODO: This gets hit by observeSingleEventOfType.  Need to fix.
            /*
            @throw [[NSException alloc] initWithName:@"InvalidEventTypeForObserver"
                                              reason:@"(observeEventType:andPreviousSiblingKeyWithBlock:withCancelBlock:)
            Cannot use
            observeEventType:andPreviousSiblingKeyWithBlock:withCancelBlock: with
            FIRDataEventTypeValue. Use observeEventType:withBlock:withCancelBlock:
            instead." userInfo:nil];
            */
        }
        let handle = FUtilitiesSwift.LUIDGenerator()
        observeChildEventWithHandle(handle, withCallbacks: [eventType: block], cancelCallback: cancelBlock)
        return handle
    }

    // If we want to distinguish between value event listeners and child event
    // listeners, like in the Java client, we can consider exporting this. If we do,
    // add argument validation. Otherwise, arguments are validated in the
    // public-facing portions of the API. Also, move the FIRDatabaseHandle logic.
    private func observeValueEventWithHandle(_ handle: DatabaseHandle, withBlock block: @escaping (DataSnapshot) -> Void, cancelCallback: ((Error) -> Void)?) {
        // Note that we don't need to copy the callbacks here, FEventRegistration
        // callback properties set to copy
        let registration = FValueEventRegistration(repo: repo, handle: handle, callback: block, cancelCallback: cancelCallback)
        DatabaseQuery.sharedQueue.async {
            self.repo.addEventRegistration(registration, forQuery: self.querySpec)
        }
    }

    // Note: as with the above method, we may wish to expose this at some point.
    private func observeChildEventWithHandle(_ handle: DatabaseHandle, withCallbacks callbacks: [DataEventType : (DataSnapshot, String?) -> Void], cancelCallback: ((Error) -> Void)?) {
        // Note that we don't need to copy the callbacks here, FEventRegistration
        // callback properties set to copy
        let registration = FChildEventRegistration(repo: repo,
                                                   handle: handle,
                                                   callbacks: callbacks,
                                                   cancelCallback: cancelCallback)
        DatabaseQuery.sharedQueue.async {
            self.repo.addEventRegistration(registration, forQuery: self.querySpec)
        }
    }

    /**
     * getDataWithCompletionBlock: is used to get the most up-to-date value for
     * this query. This method updates the cache and raises events if successful. If
     * not connected, falls back to a locally-cached value.
     *
     * @param block The block that should be called with the most up-to-date value
     * of this query, or an error if no such value could be retrieved.
     */
    @objc(getDataWithCompletionBlock:) public func getData(completion block: @escaping (_ error: Error?, _ snapshot: DataSnapshot?) -> Void) {
        DatabaseQuery.sharedQueue.async {
            self.repo.getData(self, withCompletionBlock: block)
        }
    }

    /**
     * This is equivalent to observeEventType:withBlock:, except the block is
     * immediately canceled after the initial data is returned.
     *
     * @param eventType The type of event to listen for.
     * @param block The block that should be called.  It is passed the data as a
     * FIRDataSnapshot.
     */
    @objc public func observeSingleEventOfType(_ eventType: DataEventType,
                                               withBlock block: @escaping (_ snapshot: DataSnapshot) -> Void) {
        observeSingleEventOfType(eventType,
                                 withBlock:block,
                                 withCancelBlock:nil)

    }

    /**
     * This is equivalent to observeEventType:withBlock:, except the block is
     * immediately canceled after the initial data is returned. In addition, for
     * FIRDataEventTypeChildAdded, FIRDataEventTypeChildMoved, and
     * FIRDataEventTypeChildChanged events, your block will be passed the key of the
     * previous node by priority order.
     *
     * @param eventType The type of event to listen for.
     * @param block The block that should be called.  It is passed the data as a
     * FIRDataSnapshot and the previous child's key.
     */
    @objc public func observeSingleEventOfType(_ eventType: DataEventType,
                                               andPreviousSiblingKeyWithBlock block: @escaping (_ snapshot: DataSnapshot, _ prevKey: String?) -> Void) {
        observeSingleEventOfType(eventType,
                                 andPreviousSiblingKeyWithBlock: block,
                                 withCancelBlock: nil)
    }

    /**
     * This is equivalent to observeEventType:withBlock:, except the block is
     * immediately canceled after the initial data is returned.
     *
     * The cancelBlock will be called if you do not have permission to read data at
     * this location.
     *
     * @param eventType The type of event to listen for.
     * @param block The block that should be called.  It is passed the data as a
     * FIRDataSnapshot.
     * @param cancelBlock The block that will be called if you don't have permission
     * to access this data
     */
    @objc public func observeSingleEventOfType(_ eventType: DataEventType,
                                               withBlock block: @escaping (_ snapshot: DataSnapshot) -> Void,
                                               withCancelBlock cancelBlock: ((Error) -> Void)?) {
        // XXX: user reported memory leak in method

        // "When you copy a block, any references to other blocks from within that
        // block are copied if necessary—an entire tree may be copied (from the
        // top). If you have block variables and you reference a block from within
        // the block, that block will be copied."
        // http://developer.apple.com/library/ios/#documentation/cocoa/Conceptual/Blocks/Articles/bxVariables.html#//apple_ref/doc/uid/TP40007502-CH6-SW1
        // So... we don't need to do this since inside the on: we copy this block
        // off the stack to the heap.
        // __block fbt_void_datasnapshot userCallback = [callback copy];

        observeSingleEventOfType(eventType, andPreviousSiblingKeyWithBlock: { snapshot, _ in
            block(snapshot)
        }, withCancelBlock: cancelBlock)
    }

    /**
     * This is equivalent to observeEventType:withBlock:, except the block is
     * immediately canceled after the initial data is returned. In addition, for
     * FIRDataEventTypeChildAdded, FIRDataEventTypeChildMoved, and
     * FIRDataEventTypeChildChanged events, your block will be passed the key of the
     * previous node by priority order.
     *
     * The cancelBlock will be called if you do not have permission to read data at
     * this location.
     *
     * @param eventType The type of event to listen for.
     * @param block The block that should be called.  It is passed the data as a
     * FIRDataSnapshot and the previous child's key.
     * @param cancelBlock The block that will be called if you don't have permission
     * to access this data
     */
    @objc public func observeSingleEventOfType(_ eventType: DataEventType,
                                               andPreviousSiblingKeyWithBlock block: @escaping (_ snapshot: DataSnapshot, _ prevKey: String?) -> Void,
                                               withCancelBlock cancelBlock: ((Error) -> Void)?) {
        // XXX: user reported memory leak in method

        // "When you copy a block, any references to other blocks from within that
        // block are copied if necessary—an entire tree may be copied (from the
        // top). If you have block variables and you reference a block from within
        // the block, that block will be copied."
        // http://developer.apple.com/library/ios/#documentation/cocoa/Conceptual/Blocks/Articles/bxVariables.html#//apple_ref/doc/uid/TP40007502-CH6-SW1
        // So... we don't need to do this since inside the on: we copy this block
        // off the stack to the heap.
        // __block fbt_void_datasnapshot userCallback = [callback copy];

        var handle: DatabaseHandle = 0
        var firstCall = true
        let wrappedCallback: (DataSnapshot, String?) -> Void = { snapshot, prevName in
            guard firstCall else { return }
            firstCall = false
            self.removeObserverWithHandle(handle)
            block(snapshot, prevName)
        }
        handle = observeEventType(eventType,
                                  andPreviousSiblingKeyWithBlock: wrappedCallback,
                                  withCancelBlock: { error in
            self.removeObserverWithHandle(handle)
            cancelBlock?(error)
        })
    }

    // MARK: - Detaching observers

    /**
     * Detach a block previously attached with observeEventType:withBlock:.
     *
     * @param handle The handle returned by the call to observeEventType:withBlock:
     * which we are trying to remove.
     */
    @objc public func removeObserverWithHandle(_ handle: DatabaseHandle) {
        let event = FValueEventRegistration(repo: repo, handle: handle, callback: nil, cancelCallback: nil)
        DatabaseQuery.sharedQueue.async {
            self.repo.removeEventRegistration(event, forQuery: self.querySpec)
        }
    }

    /**
     * Detach all blocks previously attached to this Firebase Database location with
     * observeEventType:withBlock:
     */
    @objc public func removeAllObservers() {
        //  XXX TODO: Use optionality instead? Or something completely different?
        removeObserverWithHandle(NSNotFound)
    }

    /**
     * By calling `keepSynced:YES` on a location, the data for that location will
     * automatically be downloaded and kept in sync, even when no listeners are
     * attached for that location. Additionally, while a location is kept synced, it
     * will not be evicted from the persistent disk cache.
     *
     * @param keepSynced Pass YES to keep this location synchronized, pass NO to
     * stop synchronization.
     */
    @objc public func keepSynced(_ keepSynced: Bool) {
        if path.getFront() == kDotInfoPrefix {
            fatalError("Can't keep query on .info tree synced (this already is the case).")
        }
        DatabaseQuery.sharedQueue.async {
            self.repo.keepQuery(self.querySpec, synced: keepSynced)
        }
    }

    // MARK: - Querying and limiting

    /**
     * queryLimitedToFirst: is used to generate a reference to a limited view of the
     * data at this location. The FIRDatabaseQuery instance returned by
     * queryLimitedToFirst: will respond to at most the first limit child nodes.
     *
     * @param limit The upper bound, inclusive, for the number of child nodes to
     * receive events for
     * @return A FIRDatabaseQuery instance, limited to at most limit child nodes.
     */
    @objc public func queryLimitedToFirst(_ limit: Int) -> DatabaseQuery {
        if queryParams.limitSet {
            fatalError("Can't call queryLimitedToFirst: if a limit was previously set")
        }
        validateLimitRange(limit)
        let params = queryParams.limitToFirst(limit)
        return DatabaseQuery(repo: repo,
                             path: path,
                             params: params,
                             orderByCalled: orderByCalled,
                             priorityMethodCalled: priorityMethodCalled)
    }

    /**
     * queryLimitedToLast: is used to generate a reference to a limited view of the
     * data at this location. The FIRDatabaseQuery instance returned by
     * queryLimitedToLast: will respond to at most the last limit child nodes.
     *
     * @param limit The upper bound, inclusive, for the number of child nodes to
     * receive events for
     * @return A FIRDatabaseQuery instance, limited to at most limit child nodes.
     */
    @objc public func queryLimitedToLast(_ limit: Int) -> DatabaseQuery {
        if queryParams.limitSet {
            fatalError("Can't call queryLimitedToLast: if a limit was previously set")
        }
        validateLimitRange(limit)
        let params = queryParams.limitToLast(limit)
        return DatabaseQuery(repo: repo,
                             path: path,
                             params: params,
                             orderByCalled: orderByCalled,
                             priorityMethodCalled: priorityMethodCalled)
    }

    /**
     * queryOrderBy: is used to generate a reference to a view of the data that's
     * been sorted by the values of a particular child key. This method is intended
     * to be used in combination with queryStartingAtValue:, queryEndingAtValue:, or
     * queryEqualToValue:.
     *
     * @param key The child key to use in ordering data visible to the returned
     * FIRDatabaseQuery
     * @return A FIRDatabaseQuery instance, ordered by the values of the specified
     * child key.
     */
    @objc public func queryOrderedByChild(_ indexPathString: String) -> DatabaseQuery {
        if indexPathString  == "$key" || indexPathString == ".key" {
            fatalError("(queryOrderedByChild:) \(indexPathString) is invalid. Use queryOrderedByKey: instead.")
        } else if indexPathString == "$priority" || indexPathString == ".priority" {
            fatalError("(queryOrderedByChild:) \(indexPathString) is invalid. Use queryOrderedByPriority: instead.")
        } else if indexPathString == "$value" || indexPathString == ".value" {
            fatalError("(queryOrderedByChild:) \(indexPathString) is invalid. Use queryOrderedByValue: instead.")
        }
        validateNoPreviousOrderByCalled()
        FValidationSwift.validateFrom("queryOrderedByChild:", validPathString: indexPathString)
        let indexPath = FPath(with: indexPathString)
        if indexPathString.isEmpty {
            fatalError("(queryOrderedByChild:) with an empty path is invalid. Use queryOrderedByValue: instead.")
        }
        let index = FPathIndex(path: indexPath)
        let params = queryParams.orderBy(index)
        validateQueryEndpointsForParams(params)
        return DatabaseQuery(repo: repo,
                             path: path,
                             params: params,
                             orderByCalled: true,
                             priorityMethodCalled: priorityMethodCalled)
    }

    /**
     * queryOrderedByKey: is used to generate a reference to a view of the data
     * that's been sorted by child key. This method is intended to be used in
     * combination with queryStartingAtValue:, queryEndingAtValue:, or
     * queryEqualToValue:.
     *
     * @return A FIRDatabaseQuery instance, ordered by child keys.
     */
    @objc public func queryOrderedByKey() -> DatabaseQuery {
        validateNoPreviousOrderByCalled()
        let params = queryParams.orderBy(FKeyIndex.keyIndex)
        validateQueryEndpointsForParams(params)
        return DatabaseQuery(repo: repo,
                             path: path,
                             params: params,
                             orderByCalled: true,
                             priorityMethodCalled: priorityMethodCalled)
    }

    /**
     * queryOrderedByValue: is used to generate a reference to a view of the data
     * that's been sorted by child value. This method is intended to be used in
     * combination with queryStartingAtValue:, queryEndingAtValue:, or
     * queryEqualToValue:.
     *
     * @return A FIRDatabaseQuery instance, ordered by child value.
     */
    @objc public func queryOrderedByValue() -> DatabaseQuery {
        validateNoPreviousOrderByCalled()
        let params = queryParams.orderBy(FValueIndex.valueIndex)
        validateQueryEndpointsForParams(params)
        return DatabaseQuery(repo: repo,
                             path: path,
                             params: params,
                             orderByCalled: true,
                             priorityMethodCalled: priorityMethodCalled)
    }

    /**
     * queryOrderedByPriority: is used to generate a reference to a view of the data
     * that's been sorted by child priority. This method is intended to be used in
     * combination with queryStartingAtValue:, queryEndingAtValue:, or
     * queryEqualToValue:.
     *
     * @return A FIRDatabaseQuery instance, ordered by child priorities.
     */
    @objc public func queryOrderedByPriority() -> DatabaseQuery {
        validateNoPreviousOrderByCalled()
        let params = queryParams.orderBy(FPriorityIndex.priorityIndex)
        validateQueryEndpointsForParams(params)
        return DatabaseQuery(repo: repo,
                             path: path,
                             params: params,
                             orderByCalled: true,
                             priorityMethodCalled: priorityMethodCalled)
    }

    /**
     * queryStartingAtValue: is used to generate a reference to a limited view of
     * the data at this location. The FIRDatabaseQuery instance returned by
     * queryStartingAtValue: will respond to events at nodes with a value greater
     * than or equal to startValue.
     *
     * @param startValue The lower bound, inclusive, for the value of data visible
     * to the returned FIRDatabaseQuery
     * @return A FIRDatabaseQuery instance, limited to data with value greater than
     * or equal to startValue
     */
    @objc public func queryStartingAtValue(_ startValue: Any?) -> DatabaseQuery {
        queryStartingAtInternal(startValue, childKey: nil, from: "queryStartingAtValue:", priorityMethod: false)
    }

    /**
     * queryStartingAtValue:childKey: is used to generate a reference to a limited
     * view of the data at this location. The FIRDatabaseQuery instance returned by
     * queryStartingAtValue:childKey will respond to events at nodes with a value
     * greater than startValue, or equal to startValue and with a key greater than
     * or equal to childKey. This is most useful when implementing pagination in a
     * case where multiple nodes can match the startValue.
     *
     * @param startValue The lower bound, inclusive, for the value of data visible
     * to the returned FIRDatabaseQuery
     * @param childKey The lower bound, inclusive, for the key of nodes with value
     * equal to startValue
     * @return A FIRDatabaseQuery instance, limited to data with value greater than
     * or equal to startValue
     */
    @objc public func queryStartingAtValue(_ startValue: Any?, childKey: String?) -> DatabaseQuery {
        if queryParams.index === FKeyIndex.keyIndex {
            fatalError("You must use queryStartingAtValue: instead of queryStartingAtValue:childKey: when using queryOrderedByKey:")
        }
        let methodName = "queryStartingAtValue:childKey:"
        if let childKey = childKey {
            FValidationSwift.validateFrom(methodName, validKey: childKey)
        }

        return queryStartingAtInternal(startValue, childKey: childKey, from: methodName, priorityMethod: false)
    }

    /**
     * queryStartingAfterValue: is used to generate a reference to a
     * limited view of the data at this location. The FIRDatabaseQuery instance
     * returned by queryStartingAfterValue: will respond to events at nodes
     * with a value greater than startAfterValue.
     *
     * @param startAfterValue The lower bound, exclusive, for the value of data
     * visible to the returned FIRDatabaseQuery
     * @return A FIRDatabaseQuery instance, limited to data with value greater
     * startAfterValue
     */
    @objc public func queryStartingAfterValue(_ startAfterValue: Any?) -> DatabaseQuery {
        queryStartingAfterValue(startAfterValue, childKey: nil)
    }

    /**
     * queryStartingAfterValue:childKey: is used to generate a reference to a
     * limited view of the data at this location. The FIRDatabaseQuery instance
     * returned by queryStartingAfterValue:childKey will respond to events at nodes
     * with a value greater than startAfterValue, or equal to startAfterValue and
     * with a key greater than childKey. This is most useful when implementing
     * pagination in a case where multiple nodes can match the startAfterValue.
     *
     * @param startAfterValue The lower bound, inclusive, for the value of data
     * visible to the returned FIRDatabaseQuery
     * @param childKey The lower bound, exclusive, for the key of nodes with value
     * equal to startAfterValue
     * @return A FIRDatabaseQuery instance, limited to data with value greater than
     * startAfterValue, or equal to startAfterValue with a key greater than childKey
     */
    @objc public func queryStartingAfterValue(_ startAfterValue: Any?, childKey: String?) -> DatabaseQuery {
        var startAfterValue = startAfterValue
        var childKey = childKey
        if self.queryParams.index === FKeyIndex.keyIndex {
            if childKey != nil {
                fatalError("You must use queryStartingAfterValue: instead of queryStartingAfterValue:childKey: when using queryOrderedByKey:")
            }
            if let startAfter = startAfterValue as? String {
                startAfterValue = FNextPushId.successor(startAfter)
            }
        } else {
            childKey = childKey.map { FNextPushId.successor($0) } ?? FUtilitiesSwift.maxName
        }
        let methodName = "queryStartingAfterValue:childKey:"
        if let childKey = childKey, childKey != FUtilitiesSwift.maxName {
            FValidationSwift.validateFrom(methodName, validKey: childKey)
        }
        return queryStartingAtInternal(startAfterValue, childKey: childKey, from: methodName, priorityMethod: false)
    }

    private func queryStartingAtInternal(_ startValue: Any?, childKey: String?, from methodName: String, priorityMethod: Bool) -> DatabaseQuery {
        validateIndexValueType(startValue, fromMethod: methodName)
        if queryParams.hasStart {
            fatalError("Can't call \(methodName) after queryStartingAtValue, queryStartingAfterValue, or queryEqualToValue was previously called")
        }
        let startNode = FSnapshotUtilitiesSwift.nodeFrom(startValue)
        let params = queryParams.startAt(startNode, childKey: childKey)
        validateQueryEndpointsForParams(params)
        return .init(repo: repo, path: path, params: params, orderByCalled: orderByCalled, priorityMethodCalled: priorityMethod || priorityMethodCalled)
    }

    /**
     * queryEndingAtValue: is used to generate a reference to a limited view of the
     * data at this location. The FIRDatabaseQuery instance returned by
     * queryEndingAtValue: will respond to events at nodes with a value less than or
     * equal to endValue.
     *
     * @param endValue The upper bound, inclusive, for the value of data visible to
     * the returned FIRDatabaseQuery
     * @return A FIRDatabaseQuery instance, limited to data with value less than or
     * equal to endValue
     */
    @objc public func queryEndingAtValue(_ endValue: Any?) -> DatabaseQuery {
        queryEndingAtInternal(endValue, childKey: nil, from: "queryEndingAtValue:", priorityMethod: false)
    }

    /**
     * queryEndingAtValue:childKey: is used to generate a reference to a limited
     * view of the data at this location. The FIRDatabaseQuery instance returned by
     * queryEndingAtValue:childKey will respond to events at nodes with a value less
     * than endValue, or equal to endValue and with a key less than or equal to
     * childKey. This is most useful when implementing pagination in a case where
     * multiple nodes can match the endValue.
     *
     * @param endValue The upper bound, inclusive, for the value of data visible to
     * the returned FIRDatabaseQuery
     * @param childKey The upper bound, inclusive, for the key of nodes with value
     * equal to endValue
     * @return A FIRDatabaseQuery instance, limited to data with value less than or
     * equal to endValue
     */
    @objc public func queryEndingAtValue(_ endValue: Any?, childKey: String?) -> DatabaseQuery {
        if queryParams.index === FKeyIndex.keyIndex {
            fatalError("You must use queryEndingAtValue: instead of queryEndingAtValue:childKey: when using queryOrderedByKey:")
        }
        let methodName = "queryEndingAtValue:childKey:"
        if let childKey = childKey {
            FValidationSwift.validateFrom(methodName, validKey: childKey)
        }
        return queryEndingAtInternal(endValue, childKey: childKey, from: methodName, priorityMethod: false)
    }

    /**
     * queryEndingBeforeValue: is used to generate a reference to a limited view of
     * the data at this location. The FIRDatabaseQuery instance returned by
     * queryEndingBeforeValue: will respond to events at nodes with a value less
     * than endValue.
     *
     * @param endValue The upper bound, exclusive, for the value of data visible to
     * the returned FIRDatabaseQuery
     * @return A FIRDatabaseQuery instance, limited to data with value less than
     * endValue
     */
    @objc public func queryEndingBeforeValue(_ endValue: Any?) -> DatabaseQuery {
        queryEndingBeforeValue(endValue, childKey: nil)
    }

    /**
     * queryEndingBeforeValue:childKey: is used to generate a reference to a limited
     * view of the data at this location. The FIRDatabaseQuery instance returned by
     * queryEndingBeforeValue:childKey will respond to events at nodes with a value
     * less than endValue, or equal to endValue and with a key less than childKey.
     *
     * @param endValue The upper bound, inclusive, for the value of data visible to
     * the returned FIRDatabaseQuery
     * @param childKey The upper bound, exclusive, for the key of nodes with value
     * equal to endValue
     * @return A FIRDatabaseQuery instance, limited to data with value less than or
     * equal to endValue
     */
    @objc public func queryEndingBeforeValue(_ endValue: Any?, childKey: String?) -> DatabaseQuery {
        var endValue = endValue
        var childKey = childKey
        if queryParams.index === FKeyIndex.keyIndex {
            if childKey != nil {
                fatalError("You must use queryEndingBeforeValue: instead of queryEndingBeforeValue:childKey: when using queryOrderedByKey:")
            }
            if let endString = endValue as? String {
                endValue = FNextPushId.predecessor(endString)
            }
        } else {
            if let child = childKey {
                childKey = FNextPushId.predecessor(child)
            } else {
                childKey = FUtilitiesSwift.minName
            }
        }
        let methodName = "queryEndingBeforeValue:childKey:"
        if let childKey = childKey, childKey != FUtilitiesSwift.minName {
            FValidationSwift.validateFrom(methodName, validKey: childKey)
        }
        return queryEndingAtInternal(endValue, childKey: childKey, from: methodName, priorityMethod: false)
    }

    private func queryEndingAtInternal(_ endValue: Any?, childKey: String?, from methodName: String, priorityMethod: Bool) -> DatabaseQuery {
        validateIndexValueType(endValue, fromMethod: methodName)
        if queryParams.hasEnd {
            fatalError("Can't call \(methodName) after queryEndingAtValue, queryEndingAfterValue, or queryEqualToValue was previously called")
        }
        let endNode = FSnapshotUtilitiesSwift.nodeFrom(endValue)
        let params = queryParams.startAt(endNode, childKey: childKey)
        validateQueryEndpointsForParams(params)
        return .init(repo: repo, path: path, params: params, orderByCalled: orderByCalled, priorityMethodCalled: priorityMethod || priorityMethodCalled)
    }

    /**
     * queryEqualToValue: is used to generate a reference to a limited view of the
     * data at this location. The FIRDatabaseQuery instance returned by
     * queryEqualToValue: will respond to events at nodes with a value equal to the
     * supplied argument.
     *
     * @param value The value that the data returned by this FIRDatabaseQuery will
     * have
     * @return A FIRDatabaseQuery instance, limited to data with the supplied value.
     */
    @objc public func queryEqualToValue(_ value: Any?) -> DatabaseQuery {
        queryEqualToInternal(value, childKey: nil, from: "queryEqualToValue:", priorityMethod: false)
    }

    /**
     * queryEqualToValue:childKey: is used to generate a reference to a limited view
     * of the data at this location. The FIRDatabaseQuery instance returned by
     * queryEqualToValue:childKey will respond to events at nodes with a value equal
     * to the supplied argument and with their key equal to childKey. There will be
     * at most one node that matches because child keys are unique.
     *
     * @param value The value that the data returned by this FIRDatabaseQuery will
     * have
     * @param childKey The name of nodes with the right value
     * @return A FIRDatabaseQuery instance, limited to data with the supplied value
     * and the key.
     */
    @objc public func queryEqualToValue(_ value: Any?, childKey: String?) -> DatabaseQuery {
        if queryParams.index === FKeyIndex.keyIndex {
            fatalError("You must use queryEqualToValue: instead of queryEqualTo:childKey: when using queryOrderedByKey:")
        }
        return queryEqualToInternal(value, childKey: childKey, from: "queryEqualToValue:childKey:", priorityMethod: false)
    }

    private func queryEqualToInternal(_ value: Any?, childKey: String?, from methodName: String, priorityMethod: Bool) -> DatabaseQuery {
        validateIndexValueType(value, fromMethod: methodName)
        if let childKey = childKey {
            FValidationSwift.validateFrom(methodName, validKey: childKey)
        }
        if queryParams.hasEnd || queryParams.hasStart {
            fatalError("Can't call \(methodName) after queryStartingAtValue, queryStartingAfterValue, queryEndingAtValue, queryEndingBeforeValue or queryEqualToValue was previously called")
        }
        let node = FSnapshotUtilitiesSwift.nodeFrom(value)
        let params = queryParams.startAt(node, childKey: childKey).endAt(node, childKey: childKey)
        validateQueryEndpointsForParams(params)
        return .init(repo: repo, path: path, params: params, orderByCalled: orderByCalled, priorityMethodCalled: priorityMethod || priorityMethodCalled)
    }

    private func validateLimitRange(_ limit: Int) {
        if limit <= 0 {
            fatalError("Limit can't be zero or less")
        }
        if (limit >= 2_147_483_648) {
            fatalError("Limit must be less than 2,147,483,648")
        }
    }

    // MARK: - Properties

    /**
     * Gets a FIRDatabaseReference for the location of this query.
     *
     * @return A FIRDatabaseReference for the location of this query.
     */
    var ref: DatabaseReference {
        .init(repo: repo, path: path)
    }

    // MARK: Private

    // Needs to be marked public due to tests...
    // We use this shared queue across all of the FQueries so things happen FIFO
    // (as opposed to dispatch_get_global_queue(0, 0) which is concurrent)
    @objc public static var sharedQueue: DispatchQueue = .init(label: "FirebaseWorker")

    convenience init(repo: FRepo, path: FPath) {
        self.init(repo: repo, path: path, params: nil, orderByCalled: false, priorityMethodCalled: false)
    }

    init(repo: FRepo, path: FPath, params: FQueryParams?, orderByCalled: Bool, priorityMethodCalled: Bool) {
        self.repo = repo
        self.path = path
        self.queryParams = params ?? .defaultInstance
        self.orderByCalled = orderByCalled
        self.priorityMethodCalled = priorityMethodCalled

        if !self.queryParams.isValid {
            fatalError("Queries are limited to two constraints")
        }
    }

    internal let repo: FRepo
    internal let path: FPath
    private let queryParams: FQueryParams
    private let orderByCalled: Bool
    private let priorityMethodCalled: Bool

    internal var querySpec: FQuerySpec {
        .init(path: path, params: queryParams)
    }

    private func validateQueryEndpointsForParams(_ params: FQueryParams) {
        if params.index === FKeyIndex.keyIndex {
            if params.hasStart {
                if params.indexStartKey != FUtilitiesSwift.minName && params.indexStartKey != FUtilitiesSwift.maxName {
                    fatalError("Can't use queryStartingAtValue:childKey:, queryStartingAfterValue:childKey:, or queryEqualTo:andChildKey: in combination with queryOrderedByKey")
                }
                if !(params.indexStartValue.val() is String) {
                    fatalError("Can't use queryStartingAtValue: or queryStartingAfterValue: with non-string types when used with queryOrderedByKey")
                }
            }
            if params.hasEnd {
                if params.indexEndKey != FUtilitiesSwift.minName && params.indexEndKey != FUtilitiesSwift.maxName {
                    fatalError("Can't use queryEndingAtValue:childKey:, queryEndingBeforeValue:childKey:, or queryEqualToValue:childKey: in combination with queryOrderedByKey")
                }
                if !(params.indexEndValue.val() is String) {
                    fatalError("Can't use queryEndingAtValue: or queryEndingBeforeValue: with non-string types when used with queryOrderedByKey")
                }
            }
        } else if params.index === FPriorityIndex.priorityIndex {
            if (params.hasStart && !FValidationSwift.validatePriorityValue(params.indexStartValue.val())) ||
                (params.hasEnd && !FValidationSwift.validatePriorityValue(params.indexEndValue.val())) {
                fatalError("When using queryOrderedByPriority, values provided to queryStartingAtValue:, queryStartingAfterValue:, queryEndingAtValue:, queryEndingBeforeValue:, or queryEqualToValue: must be valid priorities.")
            }
        }
    }

    private func validateEqualToCall(_ params: FQueryParams) {
        if queryParams.hasStart {
            fatalError("Cannot combine queryEqualToValue: and queryStartingAtValue: or queryStartingAfterValue:")
        }
        if queryParams.hasEnd {
            fatalError("Cannot combine queryEqualToValue: and queryEndingAtValue: or queryEndingBeforeValue:")
        }
    }

    private func validateNoPreviousOrderByCalled() {
        if orderByCalled {
            fatalError("Cannot use multiple queryOrderedBy calls!")
        }
    }

    private func validateIndexValueType(_ value: Any?, fromMethod method: String) {
        // XXX TODO: IS THIS ACTUALLY CORRECT? TRY IF WE COULD IN FACT USE INTs and DOUBLES and more directly
        if value != nil && !(value is NSNumber) && !(value is Int) && !(value is Double) && !(value is String) && !(value is NSNull) {
            fatalError("You can only pass nil, NSString or NSNumber to \(method)")
        }
    }

    public override var description: String {
        "(\(path) \(queryParams.description)"
    }
}
