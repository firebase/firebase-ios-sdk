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

#include "Firestore/core/include/firebase/firestore/timestamp.h"
#include "Firestore/core/src/firebase/firestore/model/database_id.h"
#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/model/snapshot_version.h"

@class FSTFieldValue;
@class FSTMaybeDocument;
@class FSTMutation;
@class FSTMutationBatch;
@class FSTMutationResult;
@class FSTObjectValue;
@class FSTQuery;
@class FSTQueryData;
@class FSTWatchChange;

@class GCFSBatchGetDocumentsResponse;
@class GCFSDocument;
@class GCFSDocumentMask;
@class GCFSListenResponse;
@class GCFSTarget;
@class GCFSTarget_DocumentsTarget;
@class GCFSTarget_QueryTarget;
@class GCFSValue;
@class GCFSWrite;
@class GCFSWriteResult;

@class GPBTimestamp;

NS_ASSUME_NONNULL_BEGIN

/**
 * Converts internal model objects to their equivalent protocol buffer form. Methods starting with
 * "encoded" convert to a protocol buffer and methods starting with "decoded" convert from a
 * protocol buffer.
 *
 * Throws an exception if a protocol buffer is missing a critical field or has a value we can't
 * interpret.
 */
@interface FSTSerializerBeta : NSObject

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithDatabaseID:(const firebase::firestore::model::DatabaseId *)databaseID
    NS_DESIGNATED_INITIALIZER;

- (GPBTimestamp *)encodedTimestamp:(const firebase::Timestamp &)timestamp;
- (firebase::Timestamp)decodedTimestamp:(GPBTimestamp *)timestamp;

- (GPBTimestamp *)encodedVersion:(const firebase::firestore::model::SnapshotVersion &)version;
- (firebase::firestore::model::SnapshotVersion)decodedVersion:(GPBTimestamp *)version;

/** Returns the database ID, such as `projects/{project id}/databases/{database_id}`. */
- (NSString *)encodedDatabaseID;

/**
 * Encodes the given document key as a fully qualified name. This includes the
 * databaseId associated with this FSTSerializerBeta and the key path.
 */
- (NSString *)encodedDocumentKey:(const firebase::firestore::model::DocumentKey &)key;
- (firebase::firestore::model::DocumentKey)decodedDocumentKey:(NSString *)key;

- (GCFSValue *)encodedFieldValue:(FSTFieldValue *)fieldValue;
- (FSTFieldValue *)decodedFieldValue:(GCFSValue *)valueProto;

- (GCFSWrite *)encodedMutation:(FSTMutation *)mutation;
- (FSTMutation *)decodedMutation:(GCFSWrite *)mutation;

- (FSTMutationResult *)decodedMutationResult:(GCFSWriteResult *)mutation
                               commitVersion:(const firebase::firestore::model::SnapshotVersion &)
                                                 commitVersion;

- (nullable NSMutableDictionary<NSString *, NSString *> *)encodedListenRequestLabelsForQueryData:
    (FSTQueryData *)queryData;

- (GCFSTarget *)encodedTarget:(FSTQueryData *)queryData;

- (GCFSTarget_DocumentsTarget *)encodedDocumentsTarget:(FSTQuery *)query;
- (FSTQuery *)decodedQueryFromDocumentsTarget:(GCFSTarget_DocumentsTarget *)target;

- (GCFSTarget_QueryTarget *)encodedQueryTarget:(FSTQuery *)query;
- (FSTQuery *)decodedQueryFromQueryTarget:(GCFSTarget_QueryTarget *)target;

- (FSTWatchChange *)decodedWatchChange:(GCFSListenResponse *)watchChange;
- (firebase::firestore::model::SnapshotVersion)versionFromListenResponse:
    (GCFSListenResponse *)watchChange;

- (GCFSDocument *)encodedDocumentWithFields:(FSTObjectValue *)objectValue
                                        key:(const firebase::firestore::model::DocumentKey &)key;

/**
 * Encodes an FSTObjectValue into a dictionary.
 * @return a new dictionary that can be assigned to a field in another proto.
 */
- (NSMutableDictionary<NSString *, GCFSValue *> *)encodedFields:(FSTObjectValue *)value;

- (FSTObjectValue *)decodedFields:(NSDictionary<NSString *, GCFSValue *> *)fields;

- (FSTMaybeDocument *)decodedMaybeDocumentFromBatch:(GCFSBatchGetDocumentsResponse *)response;

@end

NS_ASSUME_NONNULL_END
