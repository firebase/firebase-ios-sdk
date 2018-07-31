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

#import "Firestore/Source/Local/FSTMemoryRemoteDocumentCache.h"

#import "Firestore/Source/Core/FSTQuery.h"
#import "Firestore/Source/Local/FSTMemoryPersistence.h"
#import "Firestore/Source/Model/FSTDocument.h"
#import "Firestore/Source/Model/FSTDocumentDictionary.h"

#include "Firestore/core/src/firebase/firestore/model/document_key.h"

using firebase::firestore::model::DocumentKey;

NS_ASSUME_NONNULL_BEGIN

@interface FSTMemoryRemoteDocumentCache ()

/** Underlying cache of documents. */
@property(nonatomic, strong) FSTMaybeDocumentDictionary *docs;

@end

@implementation FSTMemoryRemoteDocumentCache

- (instancetype)init {
  if (self = [super init]) {
    _docs = [FSTMaybeDocumentDictionary maybeDocumentDictionary];
  }
  return self;
}

- (void)addEntry:(FSTMaybeDocument *)document {
  self.docs = [self.docs dictionaryBySettingObject:document forKey:document.key];
}

- (void)removeEntryForKey:(const DocumentKey &)key {
  self.docs = [self.docs dictionaryByRemovingObjectForKey:key];
}

- (nullable FSTMaybeDocument *)entryForKey:(const DocumentKey &)key {
  return self.docs[static_cast<FSTDocumentKey *>(key)];
}

- (FSTDocumentDictionary *)documentsMatchingQuery:(FSTQuery *)query {
  FSTDocumentDictionary *result = [FSTDocumentDictionary documentDictionary];

  // Documents are ordered by key, so we can use a prefix scan to narrow down the documents
  // we need to match the query against.
  FSTDocumentKey *prefix = [FSTDocumentKey keyWithPath:query.path.Append("")];
  NSEnumerator<FSTDocumentKey *> *enumerator = [self.docs keyEnumeratorFrom:prefix];
  for (FSTDocumentKey *key in enumerator) {
    if (!query.path.IsPrefixOf(key.path)) {
      break;
    }
    FSTMaybeDocument *maybeDoc = self.docs[key];
    if (![maybeDoc isKindOfClass:[FSTDocument class]]) {
      continue;
    }
    FSTDocument *doc = (FSTDocument *)maybeDoc;
    if ([query matchesDocument:doc]) {
      result = [result dictionaryBySettingObject:doc forKey:doc.key];
    }
  }

  return result;
}

- (int)removeOrphanedDocuments:(FSTMemoryLRUReferenceDelegate *)referenceDelegate
         throughSequenceNumber:(FSTListenSequenceNumber)upperBound {
  int count = 0;
  FSTMaybeDocumentDictionary *updatedDocs = self.docs;
  for (FSTDocumentKey *docKey in [self.docs keyEnumerator]) {
    if (![referenceDelegate isPinnedAtSequenceNumber:upperBound document:docKey]) {
      updatedDocs = [updatedDocs dictionaryByRemovingObjectForKey:docKey];
      NSLog(@"Removing %@", docKey);
      count++;
    }
  }
  self.docs = updatedDocs;
  return count;
}

@end

NS_ASSUME_NONNULL_END
