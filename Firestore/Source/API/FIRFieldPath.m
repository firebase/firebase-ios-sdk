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

#import "Firestore/Source/API/FIRFieldPath+Internal.h"

#import "Firestore/Source/Model/FSTPath.h"
#import "Firestore/Source/Util/FSTUsageValidation.h"

NS_ASSUME_NONNULL_BEGIN

@implementation FIRFieldPath

- (instancetype)initWithFields:(NSArray<NSString *> *)fieldNames {
  if (fieldNames.count == 0) {
    FSTThrowInvalidArgument(@"Invalid field path. Provided names must not be empty.");
  }

  for (int i = 0; i < fieldNames.count; ++i) {
    if (fieldNames[i].length == 0) {
      FSTThrowInvalidArgument(@"Invalid field name at index %d. Field names must not be empty.", i);
    }
  }

  return [self initPrivate:[FSTFieldPath pathWithSegments:fieldNames]];
}

+ (instancetype)documentID {
  return [[FIRFieldPath alloc] initPrivate:FSTFieldPath.keyFieldPath];
}

- (instancetype)initPrivate:(FSTFieldPath *)fieldPath {
  if (self = [super init]) {
    _internalValue = fieldPath;
  }
  return self;
}

+ (instancetype)pathWithDotSeparatedString:(NSString *)path {
  if ([[FIRFieldPath reservedCharactersRegex]
          numberOfMatchesInString:path
                          options:0
                            range:NSMakeRange(0, path.length)] > 0) {
    FSTThrowInvalidArgument(
        @"Invalid field path (%@). Paths must not contain '~', '*', '/', '[', or ']'", path);
  }
  @try {
    return [[FIRFieldPath alloc] initWithFields:[path componentsSeparatedByString:@"."]];
  } @catch (NSException *exception) {
    FSTThrowInvalidArgument(
        @"Invalid field path (%@). Paths must not be empty, begin with '.', end with '.', or "
        @"contain '..'",
        path);
  }
}

/** Matches any characters in a field path string that are reserved. */
+ (NSRegularExpression *)reservedCharactersRegex {
  static NSRegularExpression *regex = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    regex = [NSRegularExpression regularExpressionWithPattern:@"[~*/\\[\\]]" options:0 error:nil];
  });
  return regex;
}

- (id)copyWithZone:(NSZone *__nullable)zone {
  return [[[self class] alloc] initPrivate:self.internalValue];
}

- (BOOL)isEqual:(id)object {
  if (self == object) {
    return YES;
  }

  if (![object isKindOfClass:[FIRFieldPath class]]) {
    return NO;
  }

  return [self.internalValue isEqual:((FIRFieldPath *)object).internalValue];
}

- (NSUInteger)hash {
  return [self.internalValue hash];
}

@end

NS_ASSUME_NONNULL_END
