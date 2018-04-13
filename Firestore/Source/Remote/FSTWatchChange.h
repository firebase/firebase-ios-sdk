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

#include "Firestore/core/src/firebase/firestore/model/document_key.h"

@class FSTExistenceFilter;
@class FSTMaybeDocument;
@class FSTSnapshotVersion;

NS_ASSUME_NONNULL_BEGIN

/**
 * FSTWatchChange is the internal representation of the watcher API protocol buffers.
 * This is an empty abstract class so that all the different kinds of changes can have a common
 * base class.
 */
@interface FSTWatchChange : NSObject
@end

/**
 * FSTDocumentWatchChange represents a changed document and a list of target ids to which this
 * change applies. If the document has been deleted, the deleted document will be provided.
 */
@interface FSTDocumentWatchChange : FSTWatchChange

- (instancetype)initWithUpdatedTargetIDs:(NSArray<NSNumber *> *)updatedTargetIDs
                        removedTargetIDs:(NSArray<NSNumber *> *)removedTargetIDs
                             documentKey:(firebase::firestore::model::DocumentKey)documentKey
                                document:(nullable FSTMaybeDocument *)document
    NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

/** The key of the document for this change. */
- (const firebase::firestore::model::DocumentKey &)documentKey;

/** The new document applies to all of these targets. */
@property(nonatomic, strong, readonly) NSArray<NSNumber *> *updatedTargetIDs;

/** The new document is removed from all of these targets. */
@property(nonatomic, strong, readonly) NSArray<NSNumber *> *removedTargetIDs;

/**
 * The new document or DeletedDocument if it was deleted. Is null if the document went out of
 * view without the server sending a new document.
 */
@property(nonatomic, strong, readonly, nullable) FSTMaybeDocument *document;

@end

/**
 * An ExistenceFilterWatchChange applies to the targets and is required to verify the current client
 * state against expected state sent from the server.
 */
@interface FSTExistenceFilterWatchChange : FSTWatchChange

+ (instancetype)changeWithFilter:(FSTExistenceFilter *)filter targetID:(FSTTargetID)targetID;

- (instancetype)init NS_UNAVAILABLE;

@property(nonatomic, strong, readonly) FSTExistenceFilter *filter;
@property(nonatomic, assign, readonly) FSTTargetID targetID;
@end

/** FSTWatchTargetChangeState is the kind of change that happened to the watch target. */
typedef NS_ENUM(NSInteger, FSTWatchTargetChangeState) {
  FSTWatchTargetChangeStateNoChange,
  FSTWatchTargetChangeStateAdded,
  FSTWatchTargetChangeStateRemoved,
  FSTWatchTargetChangeStateCurrent,
  FSTWatchTargetChangeStateReset,
};

/** FSTWatchTargetChange is a change to a watch target. */
@interface FSTWatchTargetChange : FSTWatchChange

- (instancetype)initWithState:(FSTWatchTargetChangeState)state
                    targetIDs:(NSArray<NSNumber *> *)targetIDs
                  resumeToken:(NSData *)resumeToken
                        cause:(nullable NSError *)cause NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

/** What kind of change occurred to the watch target. */
@property(nonatomic, assign, readonly) FSTWatchTargetChangeState state;

/** The target IDs that were added/removed/set. */
@property(nonatomic, strong, readonly) NSArray<NSNumber *> *targetIDs;

/**
 * An opaque, server-assigned token that allows watching a query to be resumed after disconnecting
 * without retransmitting all the data that matches the query. The resume token essentially
 * identifies a point in time from which the server should resume sending results.
 */
@property(nonatomic, strong, readonly) NSData *resumeToken;

/** An RPC error indicating why the watch failed. */
@property(nonatomic, strong, readonly, nullable) NSError *cause;

@end

NS_ASSUME_NONNULL_END
