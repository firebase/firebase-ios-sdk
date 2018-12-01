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

#import "Firestore/Source/Model/FSTDocumentKey.h"

#include <string>
#include <utility>

#import "Firestore/Source/Core/FSTFirestoreClient.h"

#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"
#include "Firestore/core/src/firebase/firestore/util/hashing.h"
#include "Firestore/core/src/firebase/firestore/util/string_apple.h"

namespace util = firebase::firestore::util;
using firebase::firestore::model::ResourcePath;
using firebase::firestore::model::DocumentKey;

NS_ASSUME_NONNULL_BEGIN

@interface FSTDocumentKey () {
  // Forward most of the logic to the C++ implementation until FSTDocumentKey usages are completely
  // migrated.
  DocumentKey _delegate;
}
@end

@implementation FSTDocumentKey

+ (instancetype)keyWithDocumentKey:(const firebase::firestore::model::DocumentKey &)documentKey {
  return [[FSTDocumentKey alloc] initWithDocumentKey:documentKey];
}

/** Designated initializer. */
- (instancetype)initWithDocumentKey:(const DocumentKey &)key {
  if (self = [super init]) {
    _delegate = key;
  }
  return self;
}

- (const DocumentKey &)key {
  return _delegate;
}

- (BOOL)isEqual:(id)object {
  if (self == object) {
    return YES;
  }
  if (![object isKindOfClass:[FSTDocumentKey class]]) {
    return NO;
  }
  return _delegate == static_cast<FSTDocumentKey *>(object)->_delegate;
}

- (NSUInteger)hash {
  return _delegate.Hash();
}

- (NSString *)description {
  return [NSString stringWithFormat:@"<FSTDocumentKey: %s>", _delegate.ToString().c_str()];
}

/** Implements NSCopying without actually copying because FSTDocumentKeys are immutable. */
- (id)copyWithZone:(NSZone *_Nullable)zone {
  return self;
}

@end

NSString *const kDocumentKeyPath = @"__name__";

NS_ASSUME_NONNULL_END
