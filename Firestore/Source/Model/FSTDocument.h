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

#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/model/field_path.h"
#include "Firestore/core/src/firebase/firestore/model/snapshot_version.h"

@class FSTFieldValue;
@class GCFSDocument;
@class FSTObjectValue;

NS_ASSUME_NONNULL_BEGIN

/** Describes the `hasPendingWrites` state of a document. */
typedef NS_ENUM(NSInteger, FSTDocumentState) {
  /** Local mutations applied via the mutation queue. Document is potentially inconsistent. */
  FSTDocumentStateLocalMutations,
  /** Mutations applied based on a write acknowledgment. Document is potentially inconsistent. */
  FSTDocumentStateCommittedMutations,
  /** No mutations applied. Document was sent to us by Watch. */
  FSTDocumentStateSynced
};

/**
 * The result of a lookup for a given path may be an existing document or a tombstone that marks
 * the path deleted.
 */
@interface FSTMaybeDocument : NSObject <NSCopying>
- (id)init __attribute__((unavailable("Abstract base class")));
- (const firebase::firestore::model::DocumentKey &)key;
- (const firebase::firestore::model::SnapshotVersion &)version;

/**
 * Whether this document has a local mutation applied that has not yet been acknowledged by Watch.
 */
- (bool)hasPendingWrites;

@end

@interface FSTDocument : FSTMaybeDocument
+ (instancetype)documentWithData:(FSTObjectValue *)data
                             key:(firebase::firestore::model::DocumentKey)key
                         version:(firebase::firestore::model::SnapshotVersion)version
                           state:(FSTDocumentState)state;

+ (instancetype)documentWithData:(FSTObjectValue *)data
                             key:(firebase::firestore::model::DocumentKey)key
                         version:(firebase::firestore::model::SnapshotVersion)version
                           state:(FSTDocumentState)state
                           proto:(GCFSDocument *)proto;

- (nullable FSTFieldValue *)fieldForPath:(const firebase::firestore::model::FieldPath &)path;
- (bool)hasLocalMutations;
- (bool)hasCommittedMutations;

@property(nonatomic, strong, readonly) FSTObjectValue *data;

/**
 * Memoized serialized form of the document for optimization purposes (avoids repeated
 * serialization). Might be nil.
 */
@property(nonatomic, strong, readonly) GCFSDocument *proto;

@end

@interface FSTDeletedDocument : FSTMaybeDocument
+ (instancetype)documentWithKey:(firebase::firestore::model::DocumentKey)key
                        version:(firebase::firestore::model::SnapshotVersion)version
          hasCommittedMutations:(bool)committedMutations;

- (bool)hasCommittedMutations;

@end

@interface FSTUnknownDocument : FSTMaybeDocument
+ (instancetype)documentWithKey:(firebase::firestore::model::DocumentKey)key
                        version:(firebase::firestore::model::SnapshotVersion)version;
@end

/** An NSComparator suitable for comparing docs using only their keys. */
extern const NSComparator FSTDocumentComparatorByKey;

NS_ASSUME_NONNULL_END
