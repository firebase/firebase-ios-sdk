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

#import "FIRWriteBatch+Internal.h"

#import "FIRDocumentReference+Internal.h"
#import "FIRFirestore+Internal.h"
#import "FIRSetOptions+Internal.h"
#import "FSTFirestoreClient.h"
#import "FSTMutation.h"
#import "FSTUsageValidation.h"
#import "FSTUserDataConverter.h"

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
  return [self setData:data forDocument:document options:[FIRSetOptions overwrite]];
}

- (FIRWriteBatch *)setData:(NSDictionary<NSString *, id> *)data
               forDocument:(FIRDocumentReference *)document
                   options:(FIRSetOptions *)options {
  [self verifyNotCommitted];
  [self validateReference:document];
  FSTParsedSetData *parsed = [self.firestore.dataConverter parsedSetData:data options:options];
  [self.mutations addObjectsFromArray:[parsed mutationsWithKey:document.key
                                                  precondition:[FSTPrecondition none]]];
  return self;
}

- (FIRWriteBatch *)updateData:(NSDictionary<id, id> *)fields
                  forDocument:(FIRDocumentReference *)document {
  [self verifyNotCommitted];
  [self validateReference:document];
  FSTParsedUpdateData *parsed = [self.firestore.dataConverter parsedUpdateData:fields];
  [self.mutations
      addObjectsFromArray:[parsed mutationsWithKey:document.key
                                      precondition:[FSTPrecondition preconditionWithExists:YES]]];
  return self;
}

- (FIRWriteBatch *)deleteDocument:(FIRDocumentReference *)document {
  [self verifyNotCommitted];
  [self validateReference:document];
  [self.mutations addObject:[[FSTDeleteMutation alloc] initWithKey:document.key
                                                      precondition:[FSTPrecondition none]]];
  return self;
}

- (void)commitWithCompletion:(void (^)(NSError *_Nullable error))completion {
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
