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

#include "Firestore/Source/Public/FirebaseFirestore/FIRInt32Value.h"

NS_ASSUME_NONNULL_BEGIN

@implementation FIRInt32Value

- (instancetype)initWithValue:(int)value {
  self = [super init];
  if (self) {
    _value = value;
  }
  return self;
}

- (BOOL)isEqual:(id)object {
  if (self == object) {
    return YES;
  }

  if (![object isKindOfClass:[FIRInt32Value class]]) {
    return NO;
  }

  FIRInt32Value *other = (FIRInt32Value *)object;
  return self.value == other.value;
}

- (id)copyWithZone:(__unused NSZone *_Nullable)zone {
  return [[FIRInt32Value alloc] initWithValue:self.value];
}

- (NSString *)description {
  return [NSString stringWithFormat:@"<FIRInt32Value: (%d)>", self.value];
}

@end

NS_ASSUME_NONNULL_END
