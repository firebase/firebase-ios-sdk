/*
 * Copyright 2025 Google LLC
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

#include "Firestore/Source/Public/FirebaseFirestore/FIRRegexValue.h"

@implementation FIRRegexValue

- (instancetype)initWithPattern:(NSString *)pattern options:(NSString *)options {
  self = [super init];
  if (self) {
    _pattern = [pattern copy];
    _options = [options copy];
  }
  return self;
}

- (BOOL)isEqual:(nullable id)object {
  if (self == object) {
    return YES;
  }

  if (![object isKindOfClass:[FIRRegexValue class]]) {
    return NO;
  }

  FIRRegexValue *other = (FIRRegexValue *)object;
  return
      [self.pattern isEqualToString:other.pattern] && [self.options isEqualToString:other.options];
}

- (id)copyWithZone:(__unused NSZone *_Nullable)zone {
  return [[FIRRegexValue alloc] initWithPattern:self.pattern options:self.options];
}

- (NSString *)description {
  return [NSString
      stringWithFormat:@"<FIRRegexValue: (pattern:%@, options:%@)>", self.pattern, self.options];
}

@end
