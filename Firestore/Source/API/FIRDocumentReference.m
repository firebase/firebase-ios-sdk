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

#import "FIRFirestoreErrors.h"
#import "FIRSnapshotMetadata.h"
#import "Firestore/Source/API/FIRCollectionReference+Internal.h"
#import "Firestore/Source/API/FIRDocumentReference+Internal.h"
#import "Firestore/Source/API/FIRDocumentSnapshot+Internal.h"
#import "Firestore/Source/API/FIRFirestore+Internal.h"
#import "Firestore/Source/API/FIRListenerRegistration+Internal.h"
#import "Firestore/Source/API/FIRSetOptions+Internal.h"
#import "Firestore/Source/API/FSTUserDataConverter.h"
#import "Firestore/Source/Core/FSTEventManager.h"
#import "Firestore/Source/Core/FSTFirestoreClient.h"
#import "Firestore/Source/Core/FSTQuery.h"
#import "Firestore/Source/Model/FSTDocumentKey.h"
#import "Firestore/Source/Model/FSTDocumentSet.h"
#import "Firestore/Source/Model/FSTFieldValue.h"
#import "Firestore/Source/Model/FSTMutation.h"
#import "Firestore/Source/Model/FSTPath.h"
#import "Firestore/Source/Util/FSTAssert.h"
#import "Firestore/Source/Util/FSTAsyncQueryListener.h"
#import "Firestore/Source/Util/FSTUsageValidation.h"

NS_ASSUME_NONNULL_BEGIN

#pragma mark - FIRDocumentListenOptions

@interface FIRDocumentListenOptions ()

- (instancetype)initWithIncludeMetadataChanges:(BOOL)includeMetadataChanges
    NS_DESIGNATED_INITIALIZER;

@property(nonatomic, assign, readonly) BOOL includeMetadataChanges;

@end

@implementation FIRDocumentListenOptions

+ (instancetype)options {
  return [[FIRDocumentListenOptions alloc] init];
}

- (instancetype)initWithIncludeMetadataChanges:(BOOL)includeMetadataChanges {
  if (self = [super init]) {
    _includeMetadataChanges = includeMetadataChanges;
  }
  return self;
}

- (instancetype)init {
  return [self initWithIncludeMetadataChanges:NO];
}

- (instancetype)includeMetadataChanges:(BOOL)includeMetadataChanges {
  return [[FIRDocumentListenOptions alloc] initWithIncludeMetadataChanges:includeMetadataChanges];
}

@end

#pragma mark - FIRDocumentReference

@interface FIRDocumentReference ()
- (instancetype)initWithKey:(FSTDocumentKey *)key
                  firestore:(FIRFirestore *)firestore NS_DESIGNATED_INITIALIZER;
@property(nonatomic, strong, readonly) FSTDocumentKey *key;
@end

@implementation FIRDocumentReference (Internal)

+ (instancetype)referenceWithPath:(FSTResourcePath *)path firestore:(FIRFirestore *)firestore {
  if (path.length % 2 != 0) {
    FSTThrowInvalidArgument(
        @"Invalid document reference. Document references must have an even "
         "number of segments, but %@ has %d",
        path.canonicalString, path.length);
  }
  return
      [FIRDocumentReference referenceWithKey:[FSTDocumentKey keyWithPath:path] firestore:firestore];
}

+ (instancetype)referenceWithKey:(FSTDocumentKey *)key firestore:(FIRFirestore *)firestore {
  return [[FIRDocumentReference alloc] initWithKey:key firestore:firestore];
}

@end

@implementation FIRDocumentReference

- (instancetype)initWithKey:(FSTDocumentKey *)key firestore:(FIRFirestore *)firestore {
  if (self = [super init]) {
    _key = key;
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
  if (self.firestore != reference.firestore && ![self.firestore isEqual:reference.firestore])
    return NO;
  if (self.key != reference.key && ![self.key isEqualToKey:reference.key]) return NO;
  return YES;
}

- (NSUInteger)hash {
  NSUInteger hash = [self.firestore hash];
  hash = hash * 31u + [self.key hash];
  return hash;
}

#pragma mark - Public Methods

- (NSString *)documentID {
  return [self.key.path lastSegment];
}

- (FIRCollectionReference *)parent {
  FSTResourcePath *parentPath = [self.key.path pathByRemovingLastSegment];
  return [FIRCollectionReference referenceWithPath:parentPath firestore:self.firestore];
}

- (NSString *)path {
  return [self.key.path canonicalString];
}

- (FIRCollectionReference *)collectionWithPath:(NSString *)collectionPath {
  if (!collectionPath) {
    FSTThrowInvalidArgument(@"Collection path cannot be nil.");
  }
  FSTResourcePath *subPath = [FSTResourcePath pathWithString:collectionPath];
  FSTResourcePath *path = [self.key.path pathByAppendingPath:subPath];
  return [FIRCollectionReference referenceWithPath:path firestore:self.firestore];
}

- (void)setData:(NSDictionary<NSString *, id> *)documentData {
  return [self setData:documentData options:[FIRSetOptions overwrite] completion:nil];
}

- (void)setData:(NSDictionary<NSString *, id> *)documentData options:(FIRSetOptions *)options {
  return [self setData:documentData options:options completion:nil];
}

- (void)setData:(NSDictionary<NSString *, id> *)documentData
     completion:(nullable void (^)(NSError *_Nullable error))completion {
  return [self setData:documentData options:[FIRSetOptions overwrite] completion:completion];
}

- (void)setData:(NSDictionary<NSString *, id> *)documentData
        options:(FIRSetOptions *)options
     completion:(nullable void (^)(NSError *_Nullable error))completion {
  FSTParsedSetData *parsed = options.isMerge
                                 ? [self.firestore.dataConverter parsedMergeData:documentData]
                                 : [self.firestore.dataConverter parsedSetData:documentData];
  return [self.firestore.client
      writeMutations:[parsed mutationsWithKey:self.key precondition:[FSTPrecondition none]]
          completion:completion];
}

- (void)updateData:(NSDictionary<id, id> *)fields {
  return [self updateData:fields completion:nil];
}

- (void)updateData:(NSDictionary<id, id> *)fields
        completion:(nullable void (^)(NSError *_Nullable error))completion {
  FSTParsedUpdateData *parsed = [self.firestore.dataConverter parsedUpdateData:fields];
  return [self.firestore.client
      writeMutations:[parsed mutationsWithKey:self.key
                                 precondition:[FSTPrecondition preconditionWithExists:YES]]
          completion:completion];
}

- (void)deleteDocument {
  return [self deleteDocumentWithCompletion:nil];
}

- (void)deleteDocumentWithCompletion:(nullable void (^)(NSError *_Nullable error))completion {
  FSTDeleteMutation *mutation =
      [[FSTDeleteMutation alloc] initWithKey:self.key precondition:[FSTPrecondition none]];
  return [self.firestore.client writeMutations:@[ mutation ] completion:completion];
}

- (void)getDocumentWithCompletion:(void (^)(FIRDocumentSnapshot *_Nullable document,
                                            NSError *_Nullable error))completion {
  FSTListenOptions *listenOptions =
      [[FSTListenOptions alloc] initWithIncludeQueryMetadataChanges:YES
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
      // TODO(dimond): Use proper error domain
      completion(nil,
                 [NSError errorWithDomain:FIRFirestoreErrorDomain
                                     code:FIRFirestoreErrorCodeUnavailable
                                 userInfo:@{
                                   NSLocalizedDescriptionKey :
                                       @"Failed to get document because the client is offline.",
                                 }]);
    } else {
      completion(snapshot, nil);
    }
  };

  listenerRegistration =
      [self addSnapshotListenerInternalWithOptions:listenOptions listener:listener];
  dispatch_semaphore_signal(registered);
}

- (id<FIRListenerRegistration>)addSnapshotListener:(FIRDocumentSnapshotBlock)listener {
  return [self addSnapshotListenerWithOptions:nil listener:listener];
}

- (id<FIRListenerRegistration>)addSnapshotListenerWithOptions:
                                   (nullable FIRDocumentListenOptions *)options
                                                     listener:(FIRDocumentSnapshotBlock)listener {
  return [self addSnapshotListenerInternalWithOptions:[self internalOptions:options]
                                             listener:listener];
}

- (id<FIRListenerRegistration>)
addSnapshotListenerInternalWithOptions:(FSTListenOptions *)internalOptions
                              listener:(FIRDocumentSnapshotBlock)listener {
  FIRFirestore *firestore = self.firestore;
  FSTQuery *query = [FSTQuery queryWithPath:self.key.path];
  FSTDocumentKey *key = self.key;

  FSTViewSnapshotHandler snapshotHandler = ^(FSTViewSnapshot *snapshot, NSError *error) {
    if (error) {
      listener(nil, error);
      return;
    }

    FSTAssert(snapshot.documents.count <= 1, @"Too many document returned on a document query");
    FSTDocument *document = [snapshot.documents documentForKey:key];

    FIRDocumentSnapshot *result = [FIRDocumentSnapshot snapshotWithFirestore:firestore
                                                                 documentKey:key
                                                                    document:document
                                                                   fromCache:snapshot.fromCache];
    listener(result, nil);
  };

  FSTAsyncQueryListener *asyncListener =
      [[FSTAsyncQueryListener alloc] initWithDispatchQueue:self.firestore.client.userDispatchQueue
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
- (FSTListenOptions *)internalOptions:(nullable FIRDocumentListenOptions *)options {
  return
      [[FSTListenOptions alloc] initWithIncludeQueryMetadataChanges:options.includeMetadataChanges
                                     includeDocumentMetadataChanges:options.includeMetadataChanges
                                              waitForSyncWhenOnline:NO];
}

@end

NS_ASSUME_NONNULL_END
