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
#import "FIRFirestore.h"

#include "Firestore/core/src/firebase/firestore/util/autoid.h"

#import "Firestore/Source/API/FIRDocumentReference+Internal.h"
#import "Firestore/Source/API/FIRQuery+Internal.h"
#import "Firestore/Source/API/FIRQuery_Init.h"
#import "Firestore/Source/Core/FSTQuery.h"
#import "Firestore/Source/Util/FSTUsageValidation.h"

#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/model/resource_path.h"
#include "Firestore/core/src/firebase/firestore/util/string_apple.h"

namespace util = firebase::firestore::util;
using firebase::firestore::model::DocumentKey;
using firebase::firestore::model::ResourcePath;
using firebase::firestore::util::CreateAutoId;

NS_ASSUME_NONNULL_BEGIN

@interface FIRCollectionReference ()
- (instancetype)initWithPath:(const ResourcePath &)path
                   firestore:(FIRFirestore *)firestore NS_DESIGNATED_INITIALIZER;

// Mark the super class designated initializer unavailable.
- (instancetype)initWithQuery:(FSTQuery *)query
                    firestore:(FIRFirestore *)firestore
    __attribute__((unavailable("Use the initWithPath constructor of FIRCollectionReference.")));
@end

@implementation FIRCollectionReference (Internal)
+ (instancetype)referenceWithPath:(const ResourcePath &)path firestore:(FIRFirestore *)firestore {
  return [[FIRCollectionReference alloc] initWithPath:path firestore:firestore];
}
@end

@implementation FIRCollectionReference

- (instancetype)initWithPath:(const ResourcePath &)path firestore:(FIRFirestore *)firestore {
  if (path.size() % 2 != 1) {
    FSTThrowInvalidArgument(
        @"Invalid collection reference. Collection references must have an odd "
         "number of segments, but %s has %zu",
        path.CanonicalString().c_str(), path.size());
  }
  self = [super initWithQuery:[FSTQuery queryWithPath:path] firestore:firestore];
  return self;
}

// Override the designated initializer from the super class.
- (instancetype)initWithQuery:(FSTQuery *)query firestore:(FIRFirestore *)firestore {
  HARD_FAIL("Use FIRCollectionReference initWithPath: initializer.");
}

// NSObject Methods
- (BOOL)isEqual:(nullable id)other {
  if (other == self) return YES;
  if (![[other class] isEqual:[self class]]) return NO;

  return [self isEqualToReference:other];
}

- (BOOL)isEqualToReference:(nullable FIRCollectionReference *)reference {
  if (self == reference) return YES;
  if (reference == nil) return NO;
  return [self.firestore isEqual:reference.firestore] && [self.query isEqual:reference.query];
}

- (NSUInteger)hash {
  NSUInteger hash = [self.firestore hash];
  hash = hash * 31u + [self.query hash];
  return hash;
}

- (NSString *)collectionID {
  return util::WrapNSString(self.query.path.last_segment());
}

- (FIRDocumentReference *_Nullable)parent {
  const ResourcePath parentPath = self.query.path.PopLast();
  if (parentPath.empty()) {
    return nil;
  } else {
    DocumentKey key{parentPath};
    return [FIRDocumentReference referenceWithKey:key firestore:self.firestore];
  }
}

- (NSString *)path {
  return util::WrapNSString(self.query.path.CanonicalString());
}

- (FIRDocumentReference *)documentWithPath:(NSString *)documentPath {
  if (!documentPath) {
    FSTThrowInvalidArgument(@"Document path cannot be nil.");
  }
  const ResourcePath subPath = ResourcePath::FromString(util::MakeStringView(documentPath));
  const ResourcePath path = self.query.path.Append(subPath);
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
  const DocumentKey key{self.query.path.Append(CreateAutoId())};
  return [FIRDocumentReference referenceWithKey:key firestore:self.firestore];
}

@end

NS_ASSUME_NONNULL_END
