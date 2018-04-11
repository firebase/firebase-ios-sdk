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
#import "Firestore/Source/Util/FSTAssert.h"

#include "Firestore/core/src/firebase/firestore/model/resource_path.h"
#include "Firestore/core/src/firebase/firestore/util/string_apple.h"

namespace util = firebase::firestore::util;
using firebase::firestore::model::ResourcePath;

NS_ASSUME_NONNULL_BEGIN

@interface FSTDocumentKey () {
  /** The path to the document. */
  ResourcePath _path;
}
@end

@implementation FSTDocumentKey

+ (instancetype)keyWithPath:(ResourcePath)path {
  return [[FSTDocumentKey alloc] initWithPath:std::move(path)];
}

+ (instancetype)keyWithSegments:(std::initializer_list<std::string>)segments {
  return [FSTDocumentKey keyWithPath:ResourcePath(segments)];
}

+ (instancetype)keyWithPathString:(NSString *)resourcePath {
  return [FSTDocumentKey keyWithPath:ResourcePath::FromString(util::MakeStringView(resourcePath))];
}

/** Designated initializer. */
- (instancetype)initWithPath:(ResourcePath)path {
  FSTAssert([FSTDocumentKey isDocumentKey:path], @"invalid document key path: %s",
            path.CanonicalString().c_str());

  if (self = [super init]) {
    _path = path;
  }
  return self;
}

- (BOOL)isEqual:(id)object {
  if (self == object) {
    return YES;
  }
  if (![object isKindOfClass:[FSTDocumentKey class]]) {
    return NO;
  }
  return [self isEqualToKey:(FSTDocumentKey *)object];
}

- (NSUInteger)hash {
  return _path.Hash();
}

- (NSString *)description {
  return [NSString stringWithFormat:@"<FSTDocumentKey: %s>", _path.CanonicalString().c_str()];
}

/** Implements NSCopying without actually copying because FSTDocumentKeys are immutable. */
- (id)copyWithZone:(NSZone *_Nullable)zone {
  return self;
}

- (BOOL)isEqualToKey:(FSTDocumentKey *)other {
  return FSTDocumentKeyComparator(self, other) == NSOrderedSame;
}

- (NSComparisonResult)compare:(FSTDocumentKey *)other {
  return FSTDocumentKeyComparator(self, other);
}

+ (NSComparator)comparator {
  return ^NSComparisonResult(id obj1, id obj2) {
    return [obj1 compare:obj2];
  };
}

+ (BOOL)isDocumentKey:(const ResourcePath &)path {
  return path.size() % 2 == 0;
}

- (const ResourcePath &)path {
  return _path;
}

@end

const NSComparator FSTDocumentKeyComparator =
    ^NSComparisonResult(FSTDocumentKey *key1, FSTDocumentKey *key2) {
      if (key1.path < key2.path) {
        return NSOrderedAscending;
      } else if (key1.path > key2.path) {
        return NSOrderedDescending;
      } else {
        return NSOrderedSame;
      }
    };

NSString *const kDocumentKeyPath = @"__name__";

NS_ASSUME_NONNULL_END
