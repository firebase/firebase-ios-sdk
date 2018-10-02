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

#import "FIRDocumentReference.h"

#import <GRPCClient/GRPCCall.h>

#include <memory>
#include <utility>

#import "FIRFirestoreErrors.h"
#import "FIRFirestoreSource.h"
#import "FIRSnapshotMetadata.h"
#import "Firestore/Source/API/FIRCollectionReference+Internal.h"
#import "Firestore/Source/API/FIRDocumentReference+Internal.h"
#import "Firestore/Source/API/FIRDocumentSnapshot+Internal.h"
#import "Firestore/Source/API/FIRFirestore+Internal.h"
#import "Firestore/Source/API/FIRListenerRegistration+Internal.h"
#import "Firestore/Source/API/FSTUserDataConverter.h"
#import "Firestore/Source/Core/FSTEventManager.h"
#import "Firestore/Source/Core/FSTFirestoreClient.h"
#import "Firestore/Source/Core/FSTQuery.h"
#import "Firestore/Source/Model/FSTDocumentSet.h"
#import "Firestore/Source/Model/FSTFieldValue.h"
#import "Firestore/Source/Model/FSTMutation.h"
#import "Firestore/Source/Util/FSTAsyncQueryListener.h"
#import "Firestore/Source/Util/FSTUsageValidation.h"

#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/model/precondition.h"
#include "Firestore/core/src/firebase/firestore/model/resource_path.h"
#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"
#include "Firestore/core/src/firebase/firestore/util/string_apple.h"

namespace util = firebase::firestore::util;
using firebase::firestore::core::ParsedSetData;
using firebase::firestore::core::ParsedUpdateData;
using firebase::firestore::model::DocumentKey;
using firebase::firestore::model::Precondition;
using firebase::firestore::model::ResourcePath;

NS_ASSUME_NONNULL_BEGIN

#pragma mark - FIRDocumentReference

@interface FIRDocumentReference ()
- (instancetype)initWithKey:(DocumentKey)key
                  firestore:(FIRFirestore *)firestore NS_DESIGNATED_INITIALIZER;
@end

@implementation FIRDocumentReference {
  DocumentKey _key;
}

- (instancetype)initWithKey:(DocumentKey)key firestore:(FIRFirestore *)firestore {
  if (self = [super init]) {
    _key = std::move(key);
    _firestore = firestore;
  }
  return self;
}

#pragma mark - NSObject Methods

- (BOOL)isEqual:(nullable id)other {
  if (other == self) return YES;
  if (![[other class] isEqual:[self class]]) return NO;

  return [self isEqualToReference:other];
}

- (BOOL)isEqualToReference:(nullable FIRDocumentReference *)reference {
  if (self == reference) return YES;
  if (reference == nil) return NO;
  return [self.firestore isEqual:reference.firestore] && self.key == reference.key;
}

- (NSUInteger)hash {
  NSUInteger hash = [self.firestore hash];
  hash = hash * 31u + self.key.Hash();
  return hash;
}

#pragma mark - Public Methods

- (NSString *)documentID {
  return util::WrapNSString(self.key.path().last_segment());
}

- (FIRCollectionReference *)parent {
  return
      [FIRCollectionReference referenceWithPath:self.key.path().PopLast() firestore:self.firestore];
}

- (NSString *)path {
  return util::WrapNSString(self.key.path().CanonicalString());
}

- (FIRCollectionReference *)collectionWithPath:(NSString *)collectionPath {
  if (!collectionPath) {
    FSTThrowInvalidArgument(@"Collection path cannot be nil.");
  }
  const ResourcePath subPath = ResourcePath::FromString(util::MakeString(collectionPath));
  const ResourcePath path = self.key.path().Append(subPath);
  return [FIRCollectionReference referenceWithPath:path firestore:self.firestore];
}

- (void)setData:(NSDictionary<NSString *, id> *)documentData {
  return [self setData:documentData merge:NO completion:nil];
}

- (void)setData:(NSDictionary<NSString *, id> *)documentData merge:(BOOL)merge {
  return [self setData:documentData merge:merge completion:nil];
}

- (void)setData:(NSDictionary<NSString *, id> *)documentData
    mergeFields:(NSArray<id> *)mergeFields {
  return [self setData:documentData mergeFields:mergeFields completion:nil];
}

- (void)setData:(NSDictionary<NSString *, id> *)documentData
     completion:(nullable void (^)(NSError *_Nullable error))completion {
  return [self setData:documentData merge:NO completion:completion];
}

- (void)setData:(NSDictionary<NSString *, id> *)documentData
          merge:(BOOL)merge
     completion:(nullable void (^)(NSError *_Nullable error))completion {
  ParsedSetData parsed =
      merge ? [self.firestore.dataConverter parsedMergeData:documentData fieldMask:nil]
            : [self.firestore.dataConverter parsedSetData:documentData];
  return [self.firestore.client
      writeMutations:std::move(parsed).ToMutations(self.key, Precondition::None())
          completion:completion];
}

- (void)setData:(NSDictionary<NSString *, id> *)documentData
    mergeFields:(NSArray<id> *)mergeFields
     completion:(nullable void (^)(NSError *_Nullable error))completion {
  ParsedSetData parsed =
      [self.firestore.dataConverter parsedMergeData:documentData fieldMask:mergeFields];
  return [self.firestore.client
      writeMutations:std::move(parsed).ToMutations(self.key, Precondition::None())
          completion:completion];
}

- (void)updateData:(NSDictionary<id, id> *)fields {
  return [self updateData:fields completion:nil];
}

- (void)updateData:(NSDictionary<id, id> *)fields
        completion:(nullable void (^)(NSError *_Nullable error))completion {
  ParsedUpdateData parsed = [self.firestore.dataConverter parsedUpdateData:fields];
  return [self.firestore.client
      writeMutations:std::move(parsed).ToMutations(self.key, Precondition::Exists(true))
          completion:completion];
}

- (void)deleteDocument {
  return [self deleteDocumentWithCompletion:nil];
}

- (void)deleteDocumentWithCompletion:(nullable void (^)(NSError *_Nullable error))completion {
  FSTDeleteMutation *mutation =
      [[FSTDeleteMutation alloc] initWithKey:self.key precondition:Precondition::None()];
  return [self.firestore.client writeMutations:@[ mutation ] completion:completion];
}

- (void)getDocumentWithCompletion:(void (^)(FIRDocumentSnapshot *_Nullable document,
                                            NSError *_Nullable error))completion {
  return [self getDocumentWithSource:FIRFirestoreSourceDefault completion:completion];
}

- (void)getDocumentWithSource:(FIRFirestoreSource)source
                   completion:(void (^)(FIRDocumentSnapshot *_Nullable document,
                                        NSError *_Nullable error))completion {
  if (source == FIRFirestoreSourceCache) {
    [self.firestore.client getDocumentFromLocalCache:self completion:completion];
    return;
  }

  FSTListenOptions *options = [[FSTListenOptions alloc] initWithIncludeQueryMetadataChanges:YES
                                                             includeDocumentMetadataChanges:YES
                                                                      waitForSyncWhenOnline:YES];

  dispatch_semaphore_t registered = dispatch_semaphore_create(0);
  __block id<FIRListenerRegistration> listenerRegistration;
  FIRDocumentSnapshotBlock listener = ^(FIRDocumentSnapshot *snapshot, NSError *error) {
    if (error) {
      completion(nil, error);
      return;
    }

    // Remove query first before passing event to user to avoid user actions affecting the
    // now stale query.
    dispatch_semaphore_wait(registered, DISPATCH_TIME_FOREVER);
    [listenerRegistration remove];

    if (!snapshot.exists && snapshot.metadata.fromCache) {
      // TODO(dimond): Reconsider how to raise missing documents when offline.
      // If we're online and the document doesn't exist then we call the completion with
      // a document with document.exists set to false. If we're offline however, we call the
      // completion handler with an error. Two options:
      // 1) Cache the negative response from the server so we can deliver that even when you're
      //    offline.
      // 2) Actually call the completion handler with an error if the document doesn't exist when
      //    you are offline.
      completion(nil,
                 [NSError errorWithDomain:FIRFirestoreErrorDomain
                                     code:FIRFirestoreErrorCodeUnavailable
                                 userInfo:@{
                                   NSLocalizedDescriptionKey :
                                       @"Failed to get document because the client is offline.",
                                 }]);
    } else if (snapshot.exists && snapshot.metadata.fromCache &&
               source == FIRFirestoreSourceServer) {
      completion(nil,
                 [NSError errorWithDomain:FIRFirestoreErrorDomain
                                     code:FIRFirestoreErrorCodeUnavailable
                                 userInfo:@{
                                   NSLocalizedDescriptionKey :
                                       @"Failed to get document from server. (However, this "
                                       @"document does exist in the local cache. Run again "
                                       @"without setting source to FIRFirestoreSourceServer to "
                                       @"retrieve the cached document.)"
                                 }]);
    } else {
      completion(snapshot, nil);
    }
  };

  listenerRegistration = [self addSnapshotListenerInternalWithOptions:options listener:listener];
  dispatch_semaphore_signal(registered);
}

- (id<FIRListenerRegistration>)addSnapshotListener:(FIRDocumentSnapshotBlock)listener {
  return [self addSnapshotListenerWithIncludeMetadataChanges:NO listener:listener];
}

- (id<FIRListenerRegistration>)
    addSnapshotListenerWithIncludeMetadataChanges:(BOOL)includeMetadataChanges
                                         listener:(FIRDocumentSnapshotBlock)listener {
  FSTListenOptions *options =
      [self internalOptionsForIncludeMetadataChanges:includeMetadataChanges];
  return [self addSnapshotListenerInternalWithOptions:options listener:listener];
}

- (id<FIRListenerRegistration>)
    addSnapshotListenerInternalWithOptions:(FSTListenOptions *)internalOptions
                                  listener:(FIRDocumentSnapshotBlock)listener {
  FIRFirestore *firestore = self.firestore;
  FSTQuery *query = [FSTQuery queryWithPath:self.key.path()];
  const DocumentKey key = self.key;

  FSTViewSnapshotHandler snapshotHandler = ^(FSTViewSnapshot *snapshot, NSError *error) {
    if (error) {
      listener(nil, error);
      return;
    }

    HARD_ASSERT(snapshot.documents.count <= 1, "Too many document returned on a document query");
    FSTDocument *document = [snapshot.documents documentForKey:key];

    FIRDocumentSnapshot *result = [FIRDocumentSnapshot snapshotWithFirestore:firestore
                                                                 documentKey:key
                                                                    document:document
                                                                   fromCache:snapshot.fromCache];
    listener(result, nil);
  };

  FSTAsyncQueryListener *asyncListener =
      [[FSTAsyncQueryListener alloc] initWithExecutor:self.firestore.client.userExecutor
                                      snapshotHandler:snapshotHandler];

  FSTQueryListener *internalListener =
      [firestore.client listenToQuery:query
                              options:internalOptions
                  viewSnapshotHandler:[asyncListener asyncSnapshotHandler]];
  return [[FSTListenerRegistration alloc] initWithClient:self.firestore.client
                                           asyncListener:asyncListener
                                        internalListener:internalListener];
}

/** Converts the public API options object to the internal options object. */
- (FSTListenOptions *)internalOptionsForIncludeMetadataChanges:(BOOL)includeMetadataChanges {
  return [[FSTListenOptions alloc] initWithIncludeQueryMetadataChanges:includeMetadataChanges
                                        includeDocumentMetadataChanges:includeMetadataChanges
                                                 waitForSyncWhenOnline:NO];
}

@end

#pragma mark - FIRDocumentReference (Internal)

@implementation FIRDocumentReference (Internal)

+ (instancetype)referenceWithPath:(const ResourcePath &)path firestore:(FIRFirestore *)firestore {
  if (path.size() % 2 != 0) {
    FSTThrowInvalidArgument(
        @"Invalid document reference. Document references must have an even "
         "number of segments, but %s has %zu",
        path.CanonicalString().c_str(), path.size());
  }
  return [FIRDocumentReference referenceWithKey:DocumentKey{path} firestore:firestore];
}

+ (instancetype)referenceWithKey:(DocumentKey)key firestore:(FIRFirestore *)firestore {
  return [[FIRDocumentReference alloc] initWithKey:std::move(key) firestore:firestore];
}

- (const firebase::firestore::model::DocumentKey &)key {
  return _key;
}

@end

NS_ASSUME_NONNULL_END
