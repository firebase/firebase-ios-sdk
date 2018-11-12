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

#import "Firestore/Source/Core/FSTQuery.h"
#import "Firestore/Source/Model/FSTDocument.h"
#import "Firestore/Source/Model/FSTDocumentSet.h"
#import "Firestore/third_party/Immutable/FSTImmutableSortedDictionary.h"

#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"

using firebase::firestore::model::DocumentKey;

NS_ASSUME_NONNULL_BEGIN

#pragma mark - FSTDocumentViewChange

@interface FSTDocumentViewChange ()

+ (instancetype)changeWithDocument:(FSTDocument *)document type:(FSTDocumentViewChangeType)type;

- (instancetype)initWithDocument:(FSTDocument *)document
                            type:(FSTDocumentViewChangeType)type NS_DESIGNATED_INITIALIZER;

@end

@implementation FSTDocumentViewChange

+ (instancetype)changeWithDocument:(FSTDocument *)document type:(FSTDocumentViewChangeType)type {
  return [[FSTDocumentViewChange alloc] initWithDocument:document type:type];
}

- (instancetype)initWithDocument:(FSTDocument *)document type:(FSTDocumentViewChangeType)type {
  self = [super init];
  if (self) {
    _document = document;
    _type = type;
  }
  return self;
}

- (BOOL)isEqual:(id)other {
  if (self == other) {
    return YES;
  }
  if (![other isKindOfClass:[FSTDocumentViewChange class]]) {
    return NO;
  }
  FSTDocumentViewChange *otherChange = (FSTDocumentViewChange *)other;
  return [self.document isEqual:otherChange.document] && self.type == otherChange.type;
}

- (NSString *)description {
  return [NSString
      stringWithFormat:@"<FSTDocumentViewChange type:%ld doc:%@>", (long)self.type, self.document];
}

@end

#pragma mark - FSTDocumentViewChangeSet

@interface FSTDocumentViewChangeSet ()

/** The set of all changes tracked so far, with redundant changes merged. */
@property(nonatomic, strong)
    FSTImmutableSortedDictionary<FSTDocumentKey *, FSTDocumentViewChange *> *changeMap;

@end

@implementation FSTDocumentViewChangeSet

+ (instancetype)changeSet {
  return [[FSTDocumentViewChangeSet alloc] init];
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _changeMap = [FSTImmutableSortedDictionary dictionaryWithComparator:FSTDocumentKeyComparator];
  }
  return self;
}

- (NSString *)description {
  return [self.changeMap description];
}

- (void)addChange:(FSTDocumentViewChange *)change {
  const DocumentKey &key = change.document.key;
  FSTDocumentViewChange *oldChange = [self.changeMap objectForKey:key];
  if (!oldChange) {
    self.changeMap = [self.changeMap dictionaryBySettingObject:change forKey:key];
    return;
  }

  // Merge the new change with the existing change.
  if (change.type != FSTDocumentViewChangeTypeAdded &&
      oldChange.type == FSTDocumentViewChangeTypeMetadata) {
    self.changeMap = [self.changeMap dictionaryBySettingObject:change forKey:key];

  } else if (change.type == FSTDocumentViewChangeTypeMetadata &&
             oldChange.type != FSTDocumentViewChangeTypeRemoved) {
    FSTDocumentViewChange *newChange =
        [FSTDocumentViewChange changeWithDocument:change.document type:oldChange.type];
    self.changeMap = [self.changeMap dictionaryBySettingObject:newChange forKey:key];

  } else if (change.type == FSTDocumentViewChangeTypeModified &&
             oldChange.type == FSTDocumentViewChangeTypeModified) {
    FSTDocumentViewChange *newChange =
        [FSTDocumentViewChange changeWithDocument:change.document
                                             type:FSTDocumentViewChangeTypeModified];
    self.changeMap = [self.changeMap dictionaryBySettingObject:newChange forKey:key];
  } else if (change.type == FSTDocumentViewChangeTypeModified &&
             oldChange.type == FSTDocumentViewChangeTypeAdded) {
    FSTDocumentViewChange *newChange =
        [FSTDocumentViewChange changeWithDocument:change.document
                                             type:FSTDocumentViewChangeTypeAdded];
    self.changeMap = [self.changeMap dictionaryBySettingObject:newChange forKey:key];
  } else if (change.type == FSTDocumentViewChangeTypeRemoved &&
             oldChange.type == FSTDocumentViewChangeTypeAdded) {
    self.changeMap = [self.changeMap dictionaryByRemovingObjectForKey:key];
  } else if (change.type == FSTDocumentViewChangeTypeRemoved &&
             oldChange.type == FSTDocumentViewChangeTypeModified) {
    FSTDocumentViewChange *newChange =
        [FSTDocumentViewChange changeWithDocument:oldChange.document
                                             type:FSTDocumentViewChangeTypeRemoved];
    self.changeMap = [self.changeMap dictionaryBySettingObject:newChange forKey:key];
  } else if (change.type == FSTDocumentViewChangeTypeAdded &&
             oldChange.type == FSTDocumentViewChangeTypeRemoved) {
    FSTDocumentViewChange *newChange =
        [FSTDocumentViewChange changeWithDocument:change.document
                                             type:FSTDocumentViewChangeTypeModified];
    self.changeMap = [self.changeMap dictionaryBySettingObject:newChange forKey:key];
  } else {
    // This includes these cases, which don't make sense:
    // Added -> Added
    // Removed -> Removed
    // Modified -> Added
    // Removed -> Modified
    // Metadata -> Added
    // Removed -> Metadata
    HARD_FAIL("Unsupported combination of changes: %s after %s", change.type, oldChange.type);
  }
}

- (NSArray<FSTDocumentViewChange *> *)changes {
  NSMutableArray<FSTDocumentViewChange *> *changes = [NSMutableArray array];
  [self.changeMap enumerateKeysAndObjectsUsingBlock:^(FSTDocumentKey *key,
                                                      FSTDocumentViewChange *change, BOOL *stop) {
    [changes addObject:change];
  }];
  return changes;
}

@end

#pragma mark - FSTViewSnapshot

@implementation FSTViewSnapshot

- (instancetype)initWithQuery:(FSTQuery *)query
                    documents:(FSTDocumentSet *)documents
                 oldDocuments:(FSTDocumentSet *)oldDocuments
              documentChanges:(NSArray<FSTDocumentViewChange *> *)documentChanges
                    fromCache:(BOOL)fromCache
                  mutatedKeys:(DocumentKeySet)mutatedKeys
             syncStateChanged:(BOOL)syncStateChanged
      excludesMetadataChanges:(BOOL)excludesMetadataChanges {
  self = [super init];
  if (self) {
    _query = query;
    _documents = documents;
    _oldDocuments = oldDocuments;
    _documentChanges = documentChanges;
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
  NSMutableArray<FSTDocumentViewChange *> *viewChanges = [NSMutableArray array];
  for (FSTDocument *doc in documents.documentEnumerator) {
    [viewChanges
        addObject:[FSTDocumentViewChange changeWithDocument:doc
                                                       type:FSTDocumentViewChangeTypeAdded]];
  }
  return [[FSTViewSnapshot alloc]
                initWithQuery:query
                    documents:documents
                 oldDocuments:[FSTDocumentSet documentSetWithComparator:query.comparator]
              documentChanges:viewChanges
                    fromCache:fromCache
                  mutatedKeys:mutatedKeys
             syncStateChanged:YES
      excludesMetadataChanges:excludesMetadataChanges];
}

- (BOOL)hasPendingWrites {
  return _mutatedKeys.size() != 0;
}

- (NSString *)description {
  return
      [NSString stringWithFormat:
                    @"<FSTViewSnapshot query:%@ documents:%@ oldDocument:%@ changes:%@ "
                     "fromCache:%@ mutatedKeys:%zu syncStateChanged:%@ "
                     "excludesMetadataChanges%@>",
                    self.query, self.documents, self.oldDocuments, self.documentChanges,
                    (self.fromCache ? @"YES" : @"NO"), static_cast<size_t>(self.mutatedKeys.size()),
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
         [self.documentChanges isEqualToArray:other.documentChanges] &&
         self.fromCache == other.fromCache && self.mutatedKeys == other.mutatedKeys &&
         self.syncStateChanged == other.syncStateChanged &&
         self.excludesMetadataChanges == other.excludesMetadataChanges;
}

- (NSUInteger)hash {
  // Note: We are omitting `mutatedKeys` from the hash, since we don't have a straightforward
  // way to compute its hash value. Since `FSTViewSnapshot` is currently not stored in an
  // NSDictionary, this has no side effects.

  NSUInteger result = [self.query hash];
  result = 31 * result + [self.documents hash];
  result = 31 * result + [self.oldDocuments hash];
  result = 31 * result + [self.documentChanges hash];
  result = 31 * result + (self.fromCache ? 1231 : 1237);
  result = 31 * result + (self.syncStateChanged ? 1231 : 1237);
  result = 31 * result + (self.excludesMetadataChanges ? 1231 : 1237);
  return result;
}

@end

NS_ASSUME_NONNULL_END
