/*
 * Copyright 2017 Google
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import <Foundation/Foundation.h>

#import "Firestore/Source/Core/FSTTypes.h"
#import "Firestore/Source/Model/FSTDocumentVersionDictionary.h"

#include "Firestore/core/src/firebase/firestore/auth/user.h"

@class FSTDatastore;
@class FSTLocalStore;
@class FSTMutationBatch;
@class FSTMutationBatchResult;
@class FSTQuery;
@class FSTQueryData;
@class FSTRemoteEvent;
@class FSTTransaction;
@class FSTDispatchQueue;

NS_ASSUME_NONNULL_BEGIN

#pragma mark - FSTRemoteSyncer

/**
 * A protocol that describes the actions the FSTRemoteStore needs to perform on a cooperating
 * synchronization engine.
 */
@protocol FSTRemoteSyncer

/**
 * Applies one remote event to the sync engine, notifying any views of the changes, and releasing
 * any pending mutation batches that would become visible because of the snapshot version the
 * remote event contains.
 */
- (void)applyRemoteEvent:(FSTRemoteEvent *)remoteEvent;

/**
 * Rejects the listen for the given targetID. This can be triggered by the backend for any active
 * target.
 *
 * @param targetID The targetID corresponding to a listen initiated via
 *     -listenToTargetWithQueryData: on FSTRemoteStore.
 * @param error A description of the condition that has forced the rejection. Nearly always this
 *     will be an indication that the user is no longer authorized to see the data matching the
 *     target.
 */
- (void)rejectListenWithTargetID:(const firebase::firestore::model::TargetId)targetID
                           error:(NSError *)error;

/**
 * Applies the result of a successful write of a mutation batch to the sync engine, emitting
 * snapshots in any views that the mutation applies to, and removing the batch from the mutation
 * queue.
 */
- (void)applySuccessfulWriteWithResult:(FSTMutationBatchResult *)batchResult;

/**
 * Rejects the batch, removing the batch from the mutation queue, recomputing the local view of
 * any documents affected by the batch and then, emitting snapshots with the reverted value.
 */
- (void)rejectFailedWriteWithBatchID:(FSTBatchID)batchID error:(NSError *)error;

@end

/**
 * A protocol for the FSTRemoteStore online state delegate, called whenever the state of the
 * online streams of the FSTRemoteStore changes.
 * Note that this protocol only supports the watch stream for now.
 */
@protocol FSTOnlineStateDelegate <NSObject>

/** Called whenever the online state of the watch stream changes */
- (void)applyChangedOnlineState:(FSTOnlineState)onlineState;

@end

#pragma mark - FSTRemoteStore

/**
 * FSTRemoteStore handles all interaction with the backend through a simple, clean interface. This
 * class is not thread safe and should be only called from the worker dispatch queue.
 */
@interface FSTRemoteStore : NSObject

- (instancetype)initWithLocalStore:(FSTLocalStore *)localStore
                         datastore:(FSTDatastore *)datastore
               workerDispatchQueue:(FSTDispatchQueue *)queue;

- (instancetype)init NS_UNAVAILABLE;

@property(nonatomic, weak) id<FSTRemoteSyncer> syncEngine;

@property(nonatomic, weak) id<FSTOnlineStateDelegate> onlineStateDelegate;

/** Starts up the remote store, creating streams, restoring state from LocalStore, etc. */
- (void)start;

/** Shuts down the remote store, tearing down connections and otherwise cleaning up. */
- (void)shutdown;

/** Temporarily disables the network. The network can be re-enabled using 'enableNetwork:'. */
- (void)disableNetwork;

/** Re-enables the network. Only to be called as the counterpart to 'disableNetwork:'. */
- (void)enableNetwork;

/**
 * Tells the FSTRemoteStore that the currently authenticated user has changed.
 *
 * In response the remote store tears down streams and clears up any tracked operations that should
 * not persist across users. Restarts the streams if appropriate.
 */
- (void)userDidChange:(const firebase::firestore::auth::User &)user;

/** Listens to the target identified by the given FSTQueryData. */
- (void)listenToTargetWithQueryData:(FSTQueryData *)queryData;

/** Stops listening to the target with the given target ID. */
- (void)stopListeningToTargetID:(FSTTargetID)targetID;

/**
 * Tells the FSTRemoteStore that there are new mutations to process in the queue. This is typically
 * called by FSTSyncEngine after it has sent mutations to FSTLocalStore.
 *
 * In response the remote store will pull mutations from the local store until the datastore
 * instance reports that it cannot accept further in-progress writes. This mechanism serves to
 * maintain a pipeline of in-flight requests between the FSTDatastore and the server that
 * applies them.
 */
- (void)fillWritePipeline;

/** Returns a new transaction backed by this remote store. */
- (FSTTransaction *)transaction;

@end

NS_ASSUME_NONNULL_END
