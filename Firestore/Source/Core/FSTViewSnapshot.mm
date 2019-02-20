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

#import "Firestore/Source/Core/FSTViewSnapshot.h"

#include <string>
#include <utility>

#import "Firestore/Source/Core/FSTQuery.h"
#import "Firestore/Source/Model/FSTDocument.h"
#import "Firestore/Source/Model/FSTDocumentSet.h"

#include "Firestore/core/src/firebase/firestore/immutable/sorted_map.h"
#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"
#include "Firestore/core/src/firebase/firestore/util/hashing.h"
#include "Firestore/core/src/firebase/firestore/util/objc_compatibility.h"
#include "Firestore/core/src/firebase/firestore/util/string_apple.h"
#include "Firestore/core/src/firebase/firestore/util/string_format.h"
#include "absl/strings/str_join.h"

namespace objc = firebase::firestore::util::objc;
using firebase::firestore::core::DocumentViewChange;
using firebase::firestore::immutable::SortedMap;
using firebase::firestore::model::DocumentKey;
using firebase::firestore::model::DocumentKeySet;
using firebase::firestore::util::Hash;
using firebase::firestore::util::StringFormat;
using firebase::firestore::util::WrapNSString;

NS_ASSUME_NONNULL_BEGIN

@implementation FSTViewSnapshot {
  std::vector<DocumentViewChange> _documentChanges;
}

- (const std::vector<DocumentViewChange> &)documentChanges {
  return _documentChanges;
}

- (instancetype)initWithQuery:(FSTQuery *)query
                    documents:(FSTDocumentSet *)documents
                 oldDocuments:(FSTDocumentSet *)oldDocuments
              documentChanges:(std::vector<DocumentViewChange>)documentChanges
                    fromCache:(BOOL)fromCache
                  mutatedKeys:(DocumentKeySet)mutatedKeys
             syncStateChanged:(BOOL)syncStateChanged
      excludesMetadataChanges:(BOOL)excludesMetadataChanges {
  self = [super init];
  if (self) {
    _query = query;
    _documents = documents;
    _oldDocuments = oldDocuments;
    _documentChanges = std::move(documentChanges);
    _fromCache = fromCache;
    _mutatedKeys = mutatedKeys;
    _syncStateChanged = syncStateChanged;
    _excludesMetadataChanges = excludesMetadataChanges;
  }
  return self;
}

+ (instancetype)snapshotForInitialDocuments:(FSTDocumentSet *)documents
                                      query:(FSTQuery *)query
                                mutatedKeys:(DocumentKeySet)mutatedKeys
                                  fromCache:(BOOL)fromCache
                    excludesMetadataChanges:(BOOL)excludesMetadataChanges {
  std::vector<DocumentViewChange> viewChanges;
  for (FSTDocument *doc in documents.documentEnumerator) {
    viewChanges.emplace_back(doc, DocumentViewChange::Type::kAdded);
  }
  return [[FSTViewSnapshot alloc]
                initWithQuery:query
                    documents:documents
                 oldDocuments:[FSTDocumentSet documentSetWithComparator:query.comparator]
              documentChanges:std::move(viewChanges)
                    fromCache:fromCache
                  mutatedKeys:mutatedKeys
             syncStateChanged:YES
      excludesMetadataChanges:excludesMetadataChanges];
}

- (BOOL)hasPendingWrites {
  return _mutatedKeys.size() != 0;
}

- (NSString *)description {
  return [NSString
      stringWithFormat:@"<FSTViewSnapshot query:%@ documents:%@ oldDocument:%@ changes:%@ "
                        "fromCache:%@ mutatedKeys:%zu syncStateChanged:%@ "
                        "excludesMetadataChanges%@>",
                       self.query, self.documents, self.oldDocuments,
                       objc::Description(_documentChanges), (self.fromCache ? @"YES" : @"NO"),
                       static_cast<size_t>(self.mutatedKeys.size()),
                       (self.syncStateChanged ? @"YES" : @"NO"),
                       (self.excludesMetadataChanges ? @"YES" : @"NO")];
}

- (BOOL)isEqual:(id)object {
  if (self == object) {
    return YES;
  } else if (![object isKindOfClass:[FSTViewSnapshot class]]) {
    return NO;
  }

  FSTViewSnapshot *other = object;
  return [self.query isEqual:other.query] && [self.documents isEqual:other.documents] &&
         [self.oldDocuments isEqual:other.oldDocuments] &&
         _documentChanges == other.documentChanges && self.fromCache == other.fromCache &&
         self.mutatedKeys == other.mutatedKeys && self.syncStateChanged == other.syncStateChanged &&
         self.excludesMetadataChanges == other.excludesMetadataChanges;
}

- (NSUInteger)hash {
  // Note: We are omitting `mutatedKeys` from the hash, since we don't have a straightforward
  // way to compute its hash value. Since `FSTViewSnapshot` is currently not stored in an
  // NSDictionary, this has no side effects.

  NSUInteger result = [self.query hash];
  result = 31 * result + [self.documents hash];
  result = 31 * result + [self.oldDocuments hash];
  result = 31 * result + Hash(_documentChanges);
  result = 31 * result + (self.fromCache ? 1231 : 1237);
  result = 31 * result + (self.syncStateChanged ? 1231 : 1237);
  result = 31 * result + (self.excludesMetadataChanges ? 1231 : 1237);
  return result;
}

@end

NS_ASSUME_NONNULL_END
