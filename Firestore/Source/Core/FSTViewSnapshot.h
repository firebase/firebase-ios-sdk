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

#include <vector>

#include "Firestore/core/src/firebase/firestore/core/view_snapshot.h"
#include "Firestore/core/src/firebase/firestore/model/document_key_set.h"

@class FSTDocument;
@class FSTQuery;
@class FSTDocumentSet;
@class FSTViewSnapshot;

NS_ASSUME_NONNULL_BEGIN

typedef void (^FSTViewSnapshotHandler)(FSTViewSnapshot *_Nullable snapshot,
                                       NSError *_Nullable error);

/** A view snapshot is an immutable capture of the results of a query and the changes to them. */
@interface FSTViewSnapshot : NSObject

- (instancetype)initWithQuery:(FSTQuery *)query
                    documents:(FSTDocumentSet *)documents
                 oldDocuments:(FSTDocumentSet *)oldDocuments
              documentChanges:
                  (std::vector<firebase::firestore::core::DocumentViewChange>)documentChanges
                    fromCache:(BOOL)fromCache
                  mutatedKeys:(firebase::firestore::model::DocumentKeySet)mutatedKeys
             syncStateChanged:(BOOL)syncStateChanged
      excludesMetadataChanges:(BOOL)excludesMetadataChanges NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

/** Returns a view snapshot as if all documents in the snapshot were added. */
+ (instancetype)snapshotForInitialDocuments:(FSTDocumentSet *)documents
                                      query:(FSTQuery *)query
                                mutatedKeys:(firebase::firestore::model::DocumentKeySet)mutatedKeys
                                  fromCache:(BOOL)fromCache
                    excludesMetadataChanges:(BOOL)excludesMetadataChanges;

/** The query this view is tracking the results for. */
@property(nonatomic, strong, readonly) FSTQuery *query;

/** The documents currently known to be results of the query. */
@property(nonatomic, strong, readonly) FSTDocumentSet *documents;

/** The documents of the last snapshot. */
@property(nonatomic, strong, readonly) FSTDocumentSet *oldDocuments;

/** The set of changes that have been applied to the documents. */
- (const std::vector<firebase::firestore::core::DocumentViewChange> &)documentChanges;

/** Whether any document in the snapshot was served from the local cache. */
@property(nonatomic, assign, readonly, getter=isFromCache) BOOL fromCache;

/** Whether any document in the snapshot has pending local writes. */
@property(nonatomic, assign, readonly) BOOL hasPendingWrites;

/** Whether the sync state changed as part of this snapshot. */
@property(nonatomic, assign, readonly) BOOL syncStateChanged;

/** Whether this snapshot has been filtered to not include metadata changes */
@property(nonatomic, assign, readonly) BOOL excludesMetadataChanges;

/** The document in this snapshot that have unconfirmed writes. */
@property(nonatomic, assign, readonly) firebase::firestore::model::DocumentKeySet mutatedKeys;

@end

NS_ASSUME_NONNULL_END
