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

#import "FIRCollectionReference.h"

#include "Firestore/src/core/util/autoid.h"

#import "Firestore/Source/API/FIRDocumentReference+Internal.h"
#import "Firestore/Source/API/FIRQuery+Internal.h"
#import "Firestore/Source/API/FIRQuery_Init.h"
#import "Firestore/Source/Core/FSTQuery.h"
#import "Firestore/Source/Model/FSTDocumentKey.h"
#import "Firestore/Source/Model/FSTPath.h"
#import "Firestore/Source/Util/FSTAssert.h"
#import "Firestore/Source/Util/FSTUsageValidation.h"

NS_ASSUME_NONNULL_BEGIN

@interface FIRCollectionReference ()
- (instancetype)initWithPath:(FSTResourcePath *)path
                   firestore:(FIRFirestore *)firestore NS_DESIGNATED_INITIALIZER;

// Mark the super class designated initializer unavailable.
- (instancetype)initWithQuery:(FSTQuery *)query
                    firestore:(FIRFirestore *)firestore
    __attribute__((unavailable("Use the initWithPath constructor of FIRCollectionReference.")));
@end

@implementation FIRCollectionReference (Internal)
+ (instancetype)referenceWithPath:(FSTResourcePath *)path firestore:(FIRFirestore *)firestore {
  return [[FIRCollectionReference alloc] initWithPath:path firestore:firestore];
}
@end

@implementation FIRCollectionReference

- (instancetype)initWithPath:(FSTResourcePath *)path firestore:(FIRFirestore *)firestore {
  if (path.length % 2 != 1) {
    FSTThrowInvalidArgument(
        @"Invalid collection reference. Collection references must have an odd "
         "number of segments, but %@ has %d",
        path.canonicalString, path.length);
  }
  self = [super initWithQuery:[FSTQuery queryWithPath:path] firestore:firestore];
  return self;
}

// Override the designated initializer from the super class.
- (instancetype)initWithQuery:(FSTQuery *)query firestore:(FIRFirestore *)firestore {
  FSTFail(@"Use FIRCollectionReference initWithPath: initializer.");
}

- (NSString *)collectionID {
  return [self.query.path lastSegment];
}

- (FIRDocumentReference *_Nullable)parent {
  FSTResourcePath *parentPath = [self.query.path pathByRemovingLastSegment];
  if (parentPath.isEmpty) {
    return nil;
  } else {
    FSTDocumentKey *key = [FSTDocumentKey keyWithPath:parentPath];
    return [FIRDocumentReference referenceWithKey:key firestore:self.firestore];
  }
}

- (NSString *)path {
  return [self.query.path canonicalString];
}

- (FIRDocumentReference *)documentWithPath:(NSString *)documentPath {
  if (!documentPath) {
    FSTThrowInvalidArgument(@"Document path cannot be nil.");
  }
  FSTResourcePath *subPath = [FSTResourcePath pathWithString:documentPath];
  FSTResourcePath *path = [self.query.path pathByAppendingPath:subPath];
  return [FIRDocumentReference referenceWithPath:path firestore:self.firestore];
}

- (FIRDocumentReference *)addDocumentWithData:(NSDictionary<NSString *, id> *)data {
  return [self addDocumentWithData:data completion:nil];
}

- (FIRDocumentReference *)addDocumentWithData:(NSDictionary<NSString *, id> *)data
                                   completion:
                                       (nullable void (^)(NSError *_Nullable error))completion {
  FIRDocumentReference *docRef = [self documentWithAutoID];
  [docRef setData:data completion:completion];
  return docRef;
}

- (FIRDocumentReference *)documentWithAutoID {
  NSString *autoID = [NSString stringWithUTF8String:firestore::CreateAutoId().c_str()];
  FSTDocumentKey *key =
      [FSTDocumentKey keyWithPath:[self.query.path pathByAppendingSegment:autoID]];
  return [FIRDocumentReference referenceWithKey:key firestore:self.firestore];
}

@end

NS_ASSUME_NONNULL_END
