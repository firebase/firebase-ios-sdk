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

#include "Firestore/Source/Public/FirebaseFirestore/FIRBsonBinaryData.h"

NS_ASSUME_NONNULL_BEGIN

@implementation FIRBsonBinaryData

- (instancetype)initWithSubtype:(uint8_t)subtype data:(NSData *)data {
  self = [super init];
  if (self) {
    _subtype = subtype;
    _data = data;
  }
  return self;
}

- (BOOL)isEqual:(id)object {
  if (self == object) {
    return YES;
  }

  if (![object isKindOfClass:[FIRBsonBinaryData class]]) {
    return NO;
  }

  FIRBsonBinaryData *other = (FIRBsonBinaryData *)object;
  return self.subtype == other.subtype && [self.data isEqualToData:other.data];
}

- (id)copyWithZone:(__unused NSZone *_Nullable)zone {
  return [[FIRBsonBinaryData alloc] initWithSubtype:self.subtype data:self.data];
}

- (NSString *)description {
  return [NSString stringWithFormat:@"<FIRBsonBinaryData: (subtype:%u, data:%@)>",
                                    (unsigned int)self.subtype, self.data];
}

@end

NS_ASSUME_NONNULL_END
