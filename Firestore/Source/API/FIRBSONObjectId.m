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

#include "Firestore/Source/Public/FirebaseFirestore/FIRBSONObjectId.h"

@implementation FIRBSONObjectId

- (instancetype)initWithValue:(NSString *)value {
  self = [super init];
  if (self) {
    _value = [value copy];
  }
  return self;
}

- (BOOL)isEqual:(nullable id)object {
  if (self == object) {
    return YES;
  }

  if (![object isKindOfClass:[FIRBSONObjectId class]]) {
    return NO;
  }

  FIRBSONObjectId *other = (FIRBSONObjectId *)object;
  return [self.value isEqualToString:other.value];
}

- (id)copyWithZone:(__unused NSZone *_Nullable)zone {
  return [[FIRBSONObjectId alloc] initWithValue:self.value];
}

- (NSString *)description {
  return [NSString stringWithFormat:@"<FIRBSONObjectId: (%@)>", self.value];
}

@end
