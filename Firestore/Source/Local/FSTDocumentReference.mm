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

#import "Firestore/Source/Local/FSTDocumentReference.h"

#include <utility>

#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/util/comparison.h"

using firebase::firestore::model::DocumentKey;
using firebase::firestore::util::WrapCompare;

NS_ASSUME_NONNULL_BEGIN

@implementation FSTDocumentReference {
  DocumentKey _key;
}

- (instancetype)initWithKey:(DocumentKey)key ID:(int32_t)ID {
  self = [super init];
  if (self) {
    _key = std::move(key);
    _ID = ID;
  }
  return self;
}

- (BOOL)isEqual:(id)other {
  if (other == self) return YES;
  if (![[other class] isEqual:[self class]]) return NO;

  FSTDocumentReference *reference = (FSTDocumentReference *)other;

  return [self.key isEqualToKey:reference.key] && self.ID == reference.ID;
}

- (NSUInteger)hash {
  NSUInteger result = [self.key hash];
  result = result * 31u + self.ID;
  return result;
}

- (NSString *)description {
  return [NSString stringWithFormat:@"<FSTDocumentReference: key=%s, ID=%d>",
                                    self.key.ToString().c_str(), self.ID];
}

- (id)copyWithZone:(nullable NSZone *)zone {
  // FSTDocumentReference is immutable
  return self;
}

- (const firebase::firestore::model::DocumentKey &)key {
  return _key;
}

@end

#pragma mark Comparators

/** Sorts document references by key then ID. */
const NSComparator FSTDocumentReferenceComparatorByKey =
    ^NSComparisonResult(FSTDocumentReference *left, FSTDocumentReference *right) {
      NSComparisonResult result = FSTDocumentKeyComparator(left.key, right.key);
      if (result != NSOrderedSame) {
        return result;
      }
      return WrapCompare<int32_t>(left.ID, right.ID);
    };

/** Sorts document references by ID then key. */
const NSComparator FSTDocumentReferenceComparatorByID =
    ^NSComparisonResult(FSTDocumentReference *left, FSTDocumentReference *right) {
      NSComparisonResult result = WrapCompare<int32_t>(left.ID, right.ID);
      if (result != NSOrderedSame) {
        return result;
      }
      return FSTDocumentKeyComparator(left.key, right.key);
    };

NS_ASSUME_NONNULL_END
