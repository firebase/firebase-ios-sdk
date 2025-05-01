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

#include "Firestore/Source/Public/FirebaseFirestore/FIRBsonObjectId.h"

NS_ASSUME_NONNULL_BEGIN

@implementation FIRBsonObjectId

- (instancetype)initWithValue:(NSString *)value {
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

  if (![object isKindOfClass:[FIRBsonObjectId class]]) {
    return NO;
  }

  FIRBsonObjectId *other = (FIRBsonObjectId *)object;
  return [self.value isEqualToString:other.value];
}

- (id)copyWithZone:(__unused NSZone *_Nullable)zone {
  return [[FIRBsonObjectId alloc] initWithValue:self.value];
}

- (NSString *)description {
  return [NSString stringWithFormat:@"<FIRBsonObjectId: (%@)>", self.value];
}

@end

NS_ASSUME_NONNULL_END
