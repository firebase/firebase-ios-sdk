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

#include <map>

#import "Firestore/Source/Core/FSTTypes.h"
#import "Firestore/Source/Model/FSTDocumentDictionary.h"

#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/model/document_key_set.h"
#include "Firestore/core/src/firebase/firestore/model/snapshot_version.h"

@class FSTDocument;
@class FSTExistenceFilter;
@class FSTMaybeDocument;
@class FSTWatchChange;
@class FSTQueryData;

NS_ASSUME_NONNULL_BEGIN

#pragma mark - FSTTargetMapping

/**
 * TargetMapping represents a change to the documents in a query from the server. This can either
 * be an incremental Update or a full Reset.
 *
 * <p>This is an empty abstract class so that all the different kinds of changes can have a common
 * base class.
 */
@interface FSTTargetMapping : NSObject

/**
 * Strips out mapping changes that aren't actually changes. That is, if the document already
 * existed in the target, and is being added in the target, and this is not a reset, we can
 * skip doing the work to associate the document with the target because it has already been done.
 */
- (void)filterUpdatesUsingExistingKeys:
    (const firebase::firestore::model::DocumentKeySet &)existingKeys;

@end

#pragma mark - FSTResetMapping

/** The new set of documents to replace the current documents for a target. */
@interface FSTResetMapping : FSTTargetMapping

/**
 * Creates a new mapping with the keys for the given documents added. This is intended primarily
 * for testing.
 */
+ (FSTResetMapping *)mappingWithDocuments:(NSArray<FSTDocument *> *)documents;

/** The new set of documents for the target. */
- (const firebase::firestore::model::DocumentKeySet &)documents;
@end

#pragma mark - FSTUpdateMapping

/**
 * A target should update its set of documents with the given added/removed set of documents.
 */
@interface FSTUpdateMapping : FSTTargetMapping

/**
 * Creates a new mapping with the keys for the given documents added. This is intended primarily
 * for testing.
 */
+ (FSTUpdateMapping *)mappingWithAddedDocuments:(NSArray<FSTDocument *> *)added
                               removedDocuments:(NSArray<FSTDocument *> *)removed;

- (firebase::firestore::model::DocumentKeySet)applyTo:
    (const firebase::firestore::model::DocumentKeySet &)keys;

/** The documents added to the target. */
- (const firebase::firestore::model::DocumentKeySet &)addedDocuments;
/** The documents removed from the target. */
- (const firebase::firestore::model::DocumentKeySet &)removedDocuments;
@end

#pragma mark - FSTTargetChange

/**
 * Represents an update to the current status of a target, either explicitly having no new state, or
 * the new value to set. Note "current" has special meaning in the RPC protocol that implies that a
 * target is both up-to-date and consistent with the rest of the watch stream.
 */
typedef NS_ENUM(NSUInteger, FSTCurrentStatusUpdate) {
  /** The current status is not affected and should not be modified */
  FSTCurrentStatusUpdateNone,
  /** The target must be marked as no longer "current" */
  FSTCurrentStatusUpdateMarkNotCurrent,
  /** The target must be marked as "current" */
  FSTCurrentStatusUpdateMarkCurrent,
};

/**
 * A part of an FSTRemoteEvent specifying set of changes to a specific target. These changes track
 * what documents are currently included in the target as well as the current snapshot version and
 * resume token but the actual changes *to* documents are not part of the FSTTargetChange since
 * documents may be part of multiple targets.
 */
@interface FSTTargetChange : NSObject

/**
 * Creates a new target change with the given SnapshotVersion.
 */
- (instancetype)initWithSnapshotVersion:
    (firebase::firestore::model::SnapshotVersion)snapshotVersion;

/**
 * Creates a new target change with the given documents. Instances of FSTDocument are considered
 * added. Instance of FSTDeletedDocument are considered removed. This is intended primarily for
 * testing.
 */
+ (instancetype)changeWithDocuments:(NSArray<FSTMaybeDocument *> *)docs
                currentStatusUpdate:(FSTCurrentStatusUpdate)currentStatusUpdate;

/**
 * The snapshot version representing the last state at which this target received a consistent
 * snapshot from the backend.
 */
- (const firebase::firestore::model::SnapshotVersion &)snapshotVersion;

/**
 * The new "current" (synced) status of this target. Set to CurrentStatusUpdateNone if the status
 * should not be updated. Note "current" has special meaning for in the RPC protocol that implies
 * that a target is both up-to-date and consistent with the rest of the watch stream.
 */
@property(nonatomic, assign, readonly) FSTCurrentStatusUpdate currentStatusUpdate;

/** A set of changes to documents in this target. */
@property(nonatomic, strong, readonly) FSTTargetMapping *mapping;

/**
 * An opaque, server-assigned token that allows watching a query to be resumed after disconnecting
 * without retransmitting all the data that matches the query. The resume token essentially
 * identifies a point in time from which the server should resume sending results.
 */
@property(nonatomic, strong, readonly) NSData *resumeToken;

@end

#pragma mark - FSTRemoteEvent

/**
 * An event from the RemoteStore. It is split into targetChanges (changes to the state or the set
 * of documents in our watched targets) and documentUpdates (changes to the actual documents).
 */
@interface FSTRemoteEvent : NSObject

- (instancetype)
initWithSnapshotVersion:(firebase::firestore::model::SnapshotVersion)snapshotVersion
          targetChanges:(NSMutableDictionary<NSNumber *, FSTTargetChange *> *)targetChanges
        documentUpdates:
            (std::map<firebase::firestore::model::DocumentKey, FSTMaybeDocument *>)documentUpdates
         limboDocuments:(firebase::firestore::model::DocumentKeySet)limboDocuments;

/** The snapshot version this event brings us up to. */
- (const firebase::firestore::model::SnapshotVersion &)snapshotVersion;

/** A map from target to changes to the target. See TargetChange. */
@property(nonatomic, strong, readonly)
    NSDictionary<FSTBoxedTargetID *, FSTTargetChange *> *targetChanges;

/**
 * A set of which documents have changed or been deleted, along with the doc's new values
 * (if not deleted).
 */
- (const std::map<firebase::firestore::model::DocumentKey, FSTMaybeDocument *> &)documentUpdates;

- (const firebase::firestore::model::DocumentKeySet &)limboDocumentChanges;

/** Adds a document update to this remote event */
- (void)addDocumentUpdate:(FSTMaybeDocument *)document;

/** Handles an existence filter mismatch */
- (void)handleExistenceFilterMismatchForTargetID:(FSTBoxedTargetID *)targetID;

- (void)synthesizeDeleteForLimboTargetChange:(FSTTargetChange *)targetChange
                                         key:(const firebase::firestore::model::DocumentKey &)key;

@end

#pragma mark - FSTWatchChangeAggregator

/**
 * A helper class to accumulate watch changes into a FSTRemoteEvent and other target
 * information.
 */
@interface FSTWatchChangeAggregator : NSObject

- (instancetype)
initWithSnapshotVersion:(firebase::firestore::model::SnapshotVersion)snapshotVersion
          listenTargets:(NSDictionary<FSTBoxedTargetID *, FSTQueryData *> *)listenTargets
 pendingTargetResponses:(NSDictionary<FSTBoxedTargetID *, NSNumber *> *)pendingTargetResponses
    NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

/** The number of pending responses that are being waited on from watch */
@property(nonatomic, strong, readonly)
    NSMutableDictionary<FSTBoxedTargetID *, NSNumber *> *pendingTargetResponses;

/** Aggregates a watch change into the current state */
- (void)addWatchChange:(FSTWatchChange *)watchChange;

/** Aggregates all provided watch changes to the current state in order */
- (void)addWatchChanges:(NSArray<FSTWatchChange *> *)watchChanges;

/**
 * Converts the current state into a remote event with the snapshot version taken from the
 * initializer.
 */
- (FSTRemoteEvent *)remoteEvent;

/** The existence filters - if any - for the given target IDs. */
@property(nonatomic, strong, readonly)
    NSDictionary<FSTBoxedTargetID *, FSTExistenceFilter *> *existenceFilters;

@end

NS_ASSUME_NONNULL_END
