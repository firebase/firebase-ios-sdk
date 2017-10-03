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

#import "FSTDocumentKey.h"

#import "FSTAssert.h"
#import "FSTFirestoreClient.h"
#import "FSTPath.h"

NS_ASSUME_NONNULL_BEGIN

@interface FSTDocumentKey ()
/** The path to the document. */
@property(strong, nonatomic, readwrite) FSTResourcePath *path;
@end

@implementation FSTDocumentKey

+ (instancetype)keyWithPath:(FSTResourcePath *)path {
  return [[FSTDocumentKey alloc] initWithPath:path];
}

+ (instancetype)keyWithSegments:(NSArray<NSString *> *)segments {
  return [FSTDocumentKey keyWithPath:[FSTResourcePath pathWithSegments:segments]];
}

+ (instancetype)keyWithPathString:(NSString *)resourcePath {
  NSArray<NSString *> *segments = [resourcePath componentsSeparatedByString:@"/"];
  return [FSTDocumentKey keyWithSegments:segments];
}

/** Designated initializer. */
- (instancetype)initWithPath:(FSTResourcePath *)path {
  FSTAssert([FSTDocumentKey isDocumentKey:path], @"invalid document key path: %@", path);

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
  return self.path.hash;
}

- (NSString *)description {
  return [NSString stringWithFormat:@"<FSTDocumentKey: %@>", self.path];
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

+ (BOOL)isDocumentKey:(FSTResourcePath *)path {
  return path.length % 2 == 0;
}

@end

const NSComparator FSTDocumentKeyComparator =
    ^NSComparisonResult(FSTDocumentKey *key1, FSTDocumentKey *key2) {
      return [key1.path compare:key2.path];
    };

NSString *const kDocumentKeyPath = @"__name__";

NS_ASSUME_NONNULL_END
