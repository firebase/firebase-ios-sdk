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

#import "Firestore/Source/Model/FSTPath.h"

#import "Firestore/Source/Model/FSTDocumentKey.h"
#import "Firestore/Source/Util/FSTAssert.h"
#import "Firestore/Source/Util/FSTClasses.h"
#import "Firestore/Source/Util/FSTUsageValidation.h"

NS_ASSUME_NONNULL_BEGIN

@interface FSTPath ()
/** An underlying array of which a subset of elements are the segments of the path. */
@property(strong, nonatomic) NSArray<NSString *> *segments;
/** The index into the segments array of the first segment in this path. */
@property int offset;
@end

@implementation FSTPath

/**
 * Designated initializer.
 *
 * @param segments The underlying array of segments for the path.
 * @param offset The starting index in the underlying array for the subarray to use.
 * @param length The length of the subarray to use.
 */
- (instancetype)initWithSegments:(NSArray<NSString *> *)segments
                          offset:(int)offset
                          length:(int)length {
  FSTAssert(offset <= segments.count, @"offset %d out of range %d", offset, (int)segments.count);
  FSTAssert(length <= segments.count - offset, @"offset %d out of range %d", offset,
            (int)segments.count - offset);

  if (self = [super init]) {
    _segments = segments;
    _offset = offset;
    _length = length;
  }
  return self;
}

- (BOOL)isEqual:(id)object {
  if (self == object) {
    return YES;
  }
  if (![object isKindOfClass:[FSTPath class]]) {
    return NO;
  }
  FSTPath *path = object;
  return [self compare:path] == NSOrderedSame;
}

- (NSUInteger)hash {
  NSUInteger hash = 0;
  for (int i = 0; i < self.length; ++i) {
    hash += [self segmentAtIndex:i].hash;
  }
  return hash;
}

- (NSString *)description {
  return [self canonicalString];
}

- (id)objectAtIndexedSubscript:(int)index {
  return [self segmentAtIndex:index];
}

- (NSString *)segmentAtIndex:(int)index {
  FSTAssert(index < self.length, @"index %d out of range", index);
  return self.segments[self.offset + index];
}

- (NSString *)firstSegment {
  FSTAssert(!self.isEmpty, @"Cannot call firstSegment on empty path");
  return [self segmentAtIndex:0];
}

- (NSString *)lastSegment {
  FSTAssert(!self.isEmpty, @"Cannot call lastSegment on empty path");
  return [self segmentAtIndex:self.length - 1];
}

- (NSComparisonResult)compare:(FSTPath *)other {
  int length = MIN(self.length, other.length);
  for (int i = 0; i < length; ++i) {
    NSString *left = [self segmentAtIndex:i];
    NSString *right = [other segmentAtIndex:i];
    NSComparisonResult result = [left compare:right];
    if (result != NSOrderedSame) {
      return result;
    }
  }
  if (self.length < other.length) {
    return NSOrderedAscending;
  }
  if (self.length > other.length) {
    return NSOrderedDescending;
  }
  return NSOrderedSame;
}

- (instancetype)pathWithSegments:(NSArray<NSString *> *)segments
                          offset:(int)offset
                          length:(int)length {
  return [[[self class] alloc] initWithSegments:segments offset:offset length:length];
}

- (instancetype)pathByAppendingSegment:(NSString *)segment {
  int newLength = self.length + 1;
  NSMutableArray<NSString *> *segments = [NSMutableArray arrayWithCapacity:newLength];
  for (int i = 0; i < self.length; ++i) {
    [segments addObject:self[i]];
  }
  [segments addObject:segment];
  return [self pathWithSegments:segments offset:0 length:newLength];
}

- (instancetype)pathByAppendingPath:(FSTPath *)path {
  int newLength = self.length + path.length;
  NSMutableArray<NSString *> *segments = [NSMutableArray arrayWithCapacity:newLength];
  for (int i = 0; i < self.length; ++i) {
    [segments addObject:self[i]];
  }
  for (int i = 0; i < path.length; ++i) {
    [segments addObject:path[i]];
  }
  return [self pathWithSegments:segments offset:0 length:newLength];
}

- (BOOL)isEmpty {
  return self.length == 0;
}

- (instancetype)pathByRemovingFirstSegment {
  FSTAssert(!self.isEmpty, @"Cannot call pathByRemovingFirstSegment on empty path");
  return [self pathWithSegments:self.segments offset:self.offset + 1 length:self.length - 1];
}

- (instancetype)pathByRemovingFirstSegments:(int)count {
  FSTAssert(self.length >= count, @"pathByRemovingFirstSegments:%d on path of length %d", count,
            self.length);
  return
      [self pathWithSegments:self.segments offset:self.offset + count length:self.length - count];
}

- (instancetype)pathByRemovingLastSegment {
  FSTAssert(!self.isEmpty, @"Cannot call pathByRemovingLastSegment on empty path");
  return [self pathWithSegments:self.segments offset:self.offset length:self.length - 1];
}

- (BOOL)isPrefixOfPath:(FSTPath *)other {
  if (other.length < self.length) {
    return NO;
  }
  for (int i = 0; i < self.length; ++i) {
    if (![self[i] isEqual:other[i]]) {
      return NO;
    }
  }
  return YES;
}

/** Returns a standardized string representation of this path. */
- (NSString *)canonicalString {
  @throw FSTAbstractMethodException();  // NOLINT
}
@end

@implementation FSTFieldPath
+ (instancetype)pathWithSegments:(NSArray<NSString *> *)segments {
  return [[FSTFieldPath alloc] initWithSegments:segments offset:0 length:(int)segments.count];
}

+ (instancetype)pathWithServerFormat:(NSString *)fieldPath {
  NSMutableArray<NSString *> *segments = [NSMutableArray array];

  // TODO(b/37244157): Once we move to v1beta1, we should make this more strict. Right now, it
  // allows non-identifier path components, even if they aren't escaped. Technically, this will
  // mangle paths with backticks in them used in v1alpha1, but that's fine.

  const char *source = [fieldPath UTF8String];
  char *segment = (char *)malloc(strlen(source) + 1);
  char *segmentEnd = segment;

  // If we're inside '`' backticks, then we should ignore '.' dots.
  BOOL inBackticks = NO;

  char c;
  do {
    // Examine current character. This is legit even on zero-length strings because there's always
    // a null terminator.
    c = *source++;
    switch (c) {
      case '\0':  // Falls through
      case '.':
        if (!inBackticks) {
          // Segment is complete
          *segmentEnd = '\0';
          if (segment == segmentEnd) {
            FSTThrowInvalidArgument(
                @"Invalid field path (%@). Paths must not be empty, begin with "
                @"'.', end with '.', or contain '..'",
                fieldPath);
          }

          [segments addObject:[NSString stringWithUTF8String:segment]];
          segmentEnd = segment;
        } else {
          // copy into the current segment
          *segmentEnd++ = c;
        }
        break;

      case '`':
        if (inBackticks) {
          inBackticks = NO;
        } else {
          inBackticks = YES;
        }
        break;

      case '\\':
        // advance to escaped character
        c = *source++;
        // TODO(b/37244157): Make this a user-facing exception once we finalize field escaping.
        FSTAssert(c != '\0', @"Trailing escape characters not allowed in %@", fieldPath);
      // Fall through

      default:
        // copy into the current segment
        *segmentEnd++ = c;
        break;
    }
  } while (c);

  FSTAssert(!inBackticks, @"Unterminated ` in path %@", fieldPath);

  free(segment);
  return [FSTFieldPath pathWithSegments:segments];
}

+ (instancetype)keyFieldPath {
  static FSTFieldPath *keyFieldPath;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    keyFieldPath = [FSTFieldPath pathWithSegments:@[ kDocumentKeyPath ]];
  });
  return keyFieldPath;
}

+ (instancetype)emptyPath {
  static FSTFieldPath *emptyPath;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    emptyPath = [FSTFieldPath pathWithSegments:@[]];
  });
  return emptyPath;
}

/** Return YES if the string could be used as a segment in a field path without escaping. */
+ (BOOL)isValidIdentifier:(NSString *)segment {
  if (segment.length == 0) {
    return NO;
  }
  unichar first = [segment characterAtIndex:0];
  if (first != '_' && (first < 'a' || first > 'z') && (first < 'A' || first > 'Z')) {
    return NO;
  }
  for (int i = 1; i < segment.length; i++) {
    unichar c = [segment characterAtIndex:i];
    if (c != '_' && (c < 'a' || c > 'z') && (c < 'A' || c > 'Z') && (c < '0' || c > '9')) {
      return NO;
    }
  }
  return YES;
}

- (BOOL)isKeyFieldPath {
  return [self isEqual:FSTFieldPath.keyFieldPath];
}

- (NSString *)canonicalString {
  NSMutableString *result = [NSMutableString string];
  for (int i = 0; i < self.length; i++) {
    if (i > 0) {
      [result appendString:@"."];
    }

    NSString *escaped = [self[i] stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
    escaped = [escaped stringByReplacingOccurrencesOfString:@"`" withString:@"\\`"];
    if (![FSTFieldPath isValidIdentifier:escaped]) {
      escaped = [NSString stringWithFormat:@"`%@`", escaped];
    }

    [result appendString:escaped];
  }
  return result;
}

@end

@implementation FSTResourcePath
+ (instancetype)pathWithSegments:(NSArray<NSString *> *)segments {
  return [[FSTResourcePath alloc] initWithSegments:segments offset:0 length:(int)segments.count];
}

+ (instancetype)pathWithString:(NSString *)resourcePath {
  // NOTE: The client is ignorant of any path segments containing escape sequences (e.g. __id123__)
  // and just passes them through raw (they exist for legacy reasons and should not be used
  // frequently).

  if ([resourcePath rangeOfString:@"//"].location != NSNotFound) {
    FSTThrowInvalidArgument(@"Invalid path (%@). Paths must not contain // in them.", resourcePath);
  }

  NSMutableArray *segments = [[resourcePath componentsSeparatedByString:@"/"] mutableCopy];
  // We may still have an empty segment at the beginning or end if they had a leading or trailing
  // slash (which we allow).
  [segments removeObject:@""];

  return [self pathWithSegments:segments];
}

- (NSString *)canonicalString {
  // NOTE: The client is ignorant of any path segments containing escape sequences (e.g. __id123__)
  // and just passes them through raw (they exist for legacy reasons and should not be used
  // frequently).

  NSMutableString *result = [NSMutableString string];
  for (int i = 0; i < self.length; i++) {
    if (i > 0) {
      [result appendString:@"/"];
    }
    [result appendString:self[i]];
  }
  return result;
}
@end

NS_ASSUME_NONNULL_END
