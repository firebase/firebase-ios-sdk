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
#include "Firestore/core/src/firebase/firestore/model/field_value.h"
#include "Firestore/core/src/firebase/firestore/model/snapshot_version.h"
#include "absl/types/optional.h"

@class GCFSDocument;

namespace firebase {
namespace firestore {
namespace model {

enum class DocumentState;

}  // namespace model
}  // namespace firestore
}  // namespace firebase

namespace model = firebase::firestore::model;

NS_ASSUME_NONNULL_BEGIN

/**
 * The result of a lookup for a given path may be an existing document or a tombstone that marks
 * the path deleted.
 */
@interface FSTMaybeDocument : NSObject <NSCopying>
- (id)init __attribute__((unavailable("Abstract base class")));
- (const model::DocumentKey &)key;
- (const model::SnapshotVersion &)version;

/**
 * Whether this document has a local mutation applied that has not yet been acknowledged by Watch.
 */
- (bool)hasPendingWrites;

@end

@interface FSTDocument : FSTMaybeDocument
+ (instancetype)documentWithData:(model::ObjectValue)data
                             key:(model::DocumentKey)key
                         version:(model::SnapshotVersion)version
                           state:(model::DocumentState)state;

+ (instancetype)documentWithData:(model::ObjectValue)data
                             key:(model::DocumentKey)key
                         version:(model::SnapshotVersion)version
                           state:(model::DocumentState)state
                           proto:(GCFSDocument *)proto;

- (absl::optional<model::FieldValue>)fieldForPath:(const model::FieldPath &)path;
- (bool)hasLocalMutations;
- (bool)hasCommittedMutations;

@property(nonatomic, assign, readonly) const model::ObjectValue &data;
@property(nonatomic, assign, readonly) model::DocumentState documentState;

/**
 * Memoized serialized form of the document for optimization purposes (avoids repeated
 * serialization). Might be nil.
 */
@property(nullable, nonatomic, strong, readonly) GCFSDocument *proto;

@end

@interface FSTDeletedDocument : FSTMaybeDocument
+ (instancetype)documentWithKey:(model::DocumentKey)key
                        version:(model::SnapshotVersion)version
          hasCommittedMutations:(bool)committedMutations;

- (bool)hasCommittedMutations;

@end

@interface FSTUnknownDocument : FSTMaybeDocument
+ (instancetype)documentWithKey:(model::DocumentKey)key version:(model::SnapshotVersion)version;
@end

NS_ASSUME_NONNULL_END
