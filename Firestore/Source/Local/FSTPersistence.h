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

#include "Firestore/core/src/firebase/firestore/auth/user.h"

@class FSTWriteGroup;
@protocol FSTMutationQueue;
@protocol FSTQueryCache;
@protocol FSTRemoteDocumentCache;

NS_ASSUME_NONNULL_BEGIN

/**
 * FSTPersistence is the lowest-level shared interface to persistent storage in Firestore.
 *
 * FSTPersistence is used to create FSTMutationQueue and FSTRemoteDocumentCache instances backed
 * by persistence (which might be in-memory or LevelDB).
 *
 * FSTPersistence also exposes an API to create and commit FSTWriteGroup instances.
 * Implementations of FSTWriteGroup/FSTPersistence only need to guarantee that writes made
 * against the FSTWriteGroup are not made to durable storage until commitGroup:action: is called
 * here. Since memory-only storage components do not alter durable storage, they are free to ignore
 * the group.
 *
 * This contract is enough to allow the FSTLocalStore be be written independently of whether or not
 * the stored state actually is durably persisted. If persistent storage is enabled, writes are
 * grouped together to avoid inconsistent state that could cause crashes.
 *
 * Concretely, when persistent storage is enabled, the persistent versions of FSTMutationQueue,
 * FSTRemoteDocumentCache, and others (the mutators) will defer their writes into an FSTWriteGroup.
 * Once the local store has completed one logical operation, it commits the write group using
 * [FSTPersistence commitGroup:action:].
 *
 * When persistent storage is disabled, the non-persistent versions of the mutators ignore the
 * FSTWriteGroup and [FSTPersistence commitGroup:action:] is a no-op. This short-cut is allowed
 * because memory-only storage leaves no state so it cannot be inconsistent.
 *
 * This simplifies the implementations of the mutators and allows memory-only implementations to
 * supplement the persistent ones without requiring any special dual-store implementation of
 * FSTPersistence. The cost is that the FSTLocalStore needs to be slightly careful about the order
 * of its reads and writes in order to avoid relying on being able to read back uncommitted writes.
 */
@protocol FSTPersistence <NSObject>

/**
 * Starts persistent storage, opening the database or similar.
 *
 * @param error An error object that will be populated if startup fails.
 * @return YES if persistent storage started successfully, NO otherwise.
 */
- (BOOL)start:(NSError **)error;

/** Releases any resources held during eager shutdown. */
- (void)shutdown;

/**
 * Returns an FSTMutationQueue representing the persisted mutations for the given user.
 *
 * <p>Note: The implementation is free to return the same instance every time this is called for a
 * given user. In particular, the memory-backed implementation does this to emulate the persisted
 * implementation to the extent possible (e.g. in the case of uid switching from
 * sally=>jack=>sally, sally's mutation queue will be preserved).
 */
- (id<FSTMutationQueue>)mutationQueueForUser:(const firebase::firestore::auth::User &)user;

/** Creates an FSTQueryCache representing the persisted cache of queries. */
- (id<FSTQueryCache>)queryCache;

/** Creates an FSTRemoteDocumentCache representing the persisted cache of remote documents. */
- (id<FSTRemoteDocumentCache>)remoteDocumentCache;

/**
 * Creates an FSTWriteGroup with the specified action description.
 *
 * @param action A description of the action performed by this group, used for logging.
 * @return The created group.
 */
- (FSTWriteGroup *)startGroupWithAction:(NSString *)action;

/**
 * Commits all accumulated changes in the given group. If there are no changes this is a no-op.
 *
 * @param group The group of changes to write as a unit.
 */
- (void)commitGroup:(FSTWriteGroup *)group;

@end

NS_ASSUME_NONNULL_END
