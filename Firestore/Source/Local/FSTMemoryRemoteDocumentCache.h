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

#import "Firestore/Source/Local/FSTRemoteDocumentCache.h"

#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/model/document_map.h"
#include "Firestore/core/src/firebase/firestore/model/types.h"

NS_ASSUME_NONNULL_BEGIN

@class FSTLocalSerializer;
@class FSTMemoryLRUReferenceDelegate;

@interface FSTMemoryRemoteDocumentCache : NSObject <FSTRemoteDocumentCache>

- (std::vector<firebase::firestore::model::DocumentKey>)
    removeOrphanedDocuments:(FSTMemoryLRUReferenceDelegate *)referenceDelegate
      throughSequenceNumber:(firebase::firestore::model::ListenSequenceNumber)upperBound;

- (size_t)byteSizeWithSerializer:(FSTLocalSerializer *)serializer;

@end

namespace firebase {
namespace firestore {
namespace local {

class MemoryRemoteDocumentCache {
 public:
  MemoryRemoteDocumentCache();

  void AddEntry(FSTMaybeDocument *document);

  void RemoveEntry(const model::DocumentKey &key);

  FSTMaybeDocument *_Nullable Find(const model::DocumentKey &key);

  model::MaybeDocumentMap FindAll(const model::DocumentKeySet &keys);

  model::DocumentMap GetMatchingDocuments(FSTQuery *query);

  std::vector<model::DocumentKey> RemoveOrphanedDocuments(
      FSTMemoryLRUReferenceDelegate *reference_delegate, model::ListenSequenceNumber upper_bound);

  size_t ByteSize(FSTLocalSerializer *serializer);

 private:
  /** Underlying cache of documents. */
  model::MaybeDocumentMap docs_;
};

}  // namespace local
}  // namespace firestore
}  // namespace firebase

NS_ASSUME_NONNULL_END
