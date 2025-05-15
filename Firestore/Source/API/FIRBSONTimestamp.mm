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

#include "Firestore/Source/Public/FirebaseFirestore/FIRBSONTimestamp.h"

NS_ASSUME_NONNULL_BEGIN

@implementation FIRBSONTimestamp

- (instancetype)initWithSeconds:(uint32_t)seconds increment:(uint32_t)increment {
  self = [super init];
  if (self) {
    _seconds = seconds;
    _increment = increment;
  }
  return self;
}

- (BOOL)isEqual:(id)object {
  if (self == object) {
    return YES;
  }

  if (![object isKindOfClass:[FIRBSONTimestamp class]]) {
    return NO;
  }

  FIRBSONTimestamp *other = (FIRBSONTimestamp *)object;
  return self.seconds == other.seconds && self.increment == other.increment;
}

- (id)copyWithZone:(__unused NSZone *_Nullable)zone {
  return [[FIRBSONTimestamp alloc] initWithSeconds:self.seconds increment:self.increment];
}

- (NSString *)description {
  return [NSString stringWithFormat:@"<FIRBSONTimestamp: (seconds:%u, increment:%u)>", self.seconds,
                                    self.increment];
}

@end

NS_ASSUME_NONNULL_END
