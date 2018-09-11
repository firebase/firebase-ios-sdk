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

#import "FIRWriteBatch.h"

#include <utility>

#import "Firestore/Source/API/FIRDocumentReference+Internal.h"
#import "Firestore/Source/API/FIRFirestore+Internal.h"
#import "Firestore/Source/API/FIRWriteBatch+Internal.h"
#import "Firestore/Source/API/FSTUserDataConverter.h"
#import "Firestore/Source/Core/FSTFirestoreClient.h"
#import "Firestore/Source/Model/FSTMutation.h"
#import "Firestore/Source/Util/FSTUsageValidation.h"

#include "Firestore/core/src/firebase/firestore/model/precondition.h"

using firebase::firestore::core::ParsedSetData;
using firebase::firestore::core::ParsedUpdateData;
using firebase::firestore::model::Precondition;

NS_ASSUME_NONNULL_BEGIN

#pragma mark - FIRWriteBatch

@interface FIRWriteBatch ()

- (instancetype)initWithFirestore:(FIRFirestore *)firestore NS_DESIGNATED_INITIALIZER;

@property(nonatomic, strong, readonly) FIRFirestore *firestore;
@property(nonatomic, strong, readonly) NSMutableArray<FSTMutation *> *mutations;
@property(nonatomic, assign) BOOL committed;

@end

@implementation FIRWriteBatch (Internal)

+ (instancetype)writeBatchWithFirestore:(FIRFirestore *)firestore {
  return [[FIRWriteBatch alloc] initWithFirestore:firestore];
}

@end

@implementation FIRWriteBatch

- (instancetype)initWithFirestore:(FIRFirestore *)firestore {
  self = [super init];
  if (self) {
    _firestore = firestore;
    _mutations = [NSMutableArray array];
  }
  return self;
}

- (FIRWriteBatch *)setData:(NSDictionary<NSString *, id> *)data
               forDocument:(FIRDocumentReference *)document {
  return [self setData:data forDocument:document merge:NO];
}

- (FIRWriteBatch *)setData:(NSDictionary<NSString *, id> *)data
               forDocument:(FIRDocumentReference *)document
                     merge:(BOOL)merge {
  [self verifyNotCommitted];
  [self validateReference:document];
  ParsedSetData parsed = merge ? [self.firestore.dataConverter parsedMergeData:data fieldMask:nil]
                               : [self.firestore.dataConverter parsedSetData:data];
  [self.mutations
      addObjectsFromArray:std::move(parsed).ToMutations(document.key, Precondition::None())];
  return self;
}

- (FIRWriteBatch *)setData:(NSDictionary<NSString *, id> *)data
               forDocument:(FIRDocumentReference *)document
               mergeFields:(NSArray<id> *)mergeFields {
  [self verifyNotCommitted];
  [self validateReference:document];
  ParsedSetData parsed = [self.firestore.dataConverter parsedMergeData:data fieldMask:mergeFields];
  [self.mutations
      addObjectsFromArray:std::move(parsed).ToMutations(document.key, Precondition::None())];
  return self;
}

- (FIRWriteBatch *)updateData:(NSDictionary<id, id> *)fields
                  forDocument:(FIRDocumentReference *)document {
  [self verifyNotCommitted];
  [self validateReference:document];
  ParsedUpdateData parsed = [self.firestore.dataConverter parsedUpdateData:fields];
  [self.mutations
      addObjectsFromArray:std::move(parsed).ToMutations(document.key, Precondition::Exists(true))];
  return self;
}

- (FIRWriteBatch *)deleteDocument:(FIRDocumentReference *)document {
  [self verifyNotCommitted];
  [self validateReference:document];
  [self.mutations addObject:[[FSTDeleteMutation alloc] initWithKey:document.key
                                                      precondition:Precondition::None()]];
  return self;
}

- (void)commit {
  [self commitWithCompletion:nil];
}

- (void)commitWithCompletion:(nullable void (^)(NSError *_Nullable error))completion {
  [self verifyNotCommitted];
  self.committed = TRUE;
  [self.firestore.client writeMutations:self.mutations completion:completion];
}

- (void)verifyNotCommitted {
  if (self.committed) {
    FSTThrowInvalidUsage(@"FIRIllegalStateException",
                         @"A write batch can no longer be used after commit has been called.");
  }
}

- (void)validateReference:(FIRDocumentReference *)reference {
  if (reference.firestore != self.firestore) {
    FSTThrowInvalidArgument(@"Provided document reference is from a different Firestore instance.");
  }
}

@end

NS_ASSUME_NONNULL_END
