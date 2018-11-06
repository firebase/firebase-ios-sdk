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

#include "Firestore/core/src/firebase/firestore/model/document_key_set.h"

using firebase::firestore::model::DocumentKeySet;

@class FSTDocument;
@class FSTQuery;
@class FSTDocumentSet;
@class FSTViewSnapshot;

NS_ASSUME_NONNULL_BEGIN

#pragma mark - FSTDocumentViewChange

/**
 * The types of changes that can happen to a document with respect to a view.
 * NOTE: We sort document changes by their type, so the ordering of this enum is significant.
 */
typedef NS_ENUM(NSInteger, FSTDocumentViewChangeType) {
  FSTDocumentViewChangeTypeRemoved = 0,
  FSTDocumentViewChangeTypeAdded,
  FSTDocumentViewChangeTypeModified,
  FSTDocumentViewChangeTypeMetadata,
};

/** A change to a single document's state within a view. */
@interface FSTDocumentViewChange : NSObject

- (id)init __attribute__((unavailable("Use a static constructor method.")));

+ (instancetype)changeWithDocument:(FSTDocument *)document type:(FSTDocumentViewChangeType)type;

/** The type of change for the document. */
@property(nonatomic, assign, readonly) FSTDocumentViewChangeType type;
/** The document whose status changed. */
@property(nonatomic, strong, readonly) FSTDocument *document;

@end

#pragma mark - FSTDocumentChangeSet

/** The possibly states a document can be in w.r.t syncing from local storage to the backend. */
typedef NS_ENUM(NSInteger, FSTSyncState) {
  FSTSyncStateNone = 0,
  FSTSyncStateLocal,
  FSTSyncStateSynced,
};

/** A set of changes to documents with respect to a view. This set is mutable. */
@interface FSTDocumentViewChangeSet : NSObject

/** Returns a new empty change set. */
+ (instancetype)changeSet;

/** Takes a new change and applies it to the set. */
- (void)addChange:(FSTDocumentViewChange *)change;

/** Returns the set of all changes tracked in this set. */
- (NSArray<FSTDocumentViewChange *> *)changes;

@end

#pragma mark - FSTViewSnapshot

typedef void (^FSTViewSnapshotHandler)(FSTViewSnapshot *_Nullable snapshot,
                                       NSError *_Nullable error);

/** A view snapshot is an immutable capture of the results of a query and the changes to them. */
@interface FSTViewSnapshot : NSObject

- (instancetype)initWithQuery:(FSTQuery *)query
                    documents:(FSTDocumentSet *)documents
                 oldDocuments:(FSTDocumentSet *)oldDocuments
              documentChanges:(NSArray<FSTDocumentViewChange *> *)documentChanges
                    fromCache:(BOOL)fromCache
                  mutatedKeys:(DocumentKeySet)mutatedKeys
             syncStateChanged:(BOOL)syncStateChanged
      excludesMetadataChanges:(BOOL)excludesMetadataChanges NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

/** Returns a view snapshot as if all documents in the snapshot were added. */
+ (instancetype)snapshotForInitialDocuments:(FSTDocumentSet *)documents
                                      query:(FSTQuery *)query
                                mutatedKeys:(DocumentKeySet)mutatedKeys
                                  fromCache:(BOOL)fromCache
                    excludesMetadataChanges:(BOOL)excludesMetadataChanges;

/** The query this view is tracking the results for. */
@property(nonatomic, strong, readonly) FSTQuery *query;

/** The documents currently known to be results of the query. */
@property(nonatomic, strong, readonly) FSTDocumentSet *documents;

/** The documents of the last snapshot. */
@property(nonatomic, strong, readonly) FSTDocumentSet *oldDocuments;

/** The set of changes that have been applied to the documents. */
@property(nonatomic, strong, readonly) NSArray<FSTDocumentViewChange *> *documentChanges;

/** Whether any document in the snapshot was served from the local cache. */
@property(nonatomic, assign, readonly, getter=isFromCache) BOOL fromCache;

/** Whether any document in the snapshot has pending local writes. */
@property(nonatomic, assign, readonly) BOOL hasPendingWrites;

/** Whether the sync state changed as part of this snapshot. */
@property(nonatomic, assign, readonly) BOOL syncStateChanged;

/** Whether this snapshot has been filtered to not include metadata changes */
@property(nonatomic, assign, readonly) BOOL excludesMetadataChanges;

/** The document in this snapshot that have unconfirmed writes. */
@property(nonatomic, assign, readonly) DocumentKeySet mutatedKeys;

@end

NS_ASSUME_NONNULL_END
