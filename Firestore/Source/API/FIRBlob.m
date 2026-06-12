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

#include "Firestore/Source/Public/FirebaseFirestore/FIRBlob.h"

@implementation FIRBlob

- (instancetype)initWithBytes:(NSData *)bytes subtype:(uint8_t)subtype isBSON:(BOOL)isBSON {
  self = [super init];
  if (self) {
    _subtype = subtype;
    _bytes = [bytes copy];
    _BSON = isBSON;
  }
  return self;
}

+ (instancetype)blobWithBytes:(NSData *)bytes {
  return [[FIRBlob alloc] initWithBytes:bytes subtype:0 isBSON:NO];
}

+ (instancetype)blobWithBSONBinary:(NSData *)bytes {
  return [[FIRBlob alloc] initWithBytes:bytes subtype:0 isBSON:YES];
}

+ (instancetype)blobWithBSONBinary:(NSData *)bytes subtype:(uint8_t)subtype {
  return [[FIRBlob alloc] initWithBytes:bytes subtype:subtype isBSON:YES];
}

- (BOOL)isEqual:(nullable id)object {
  if (self == object) {
    return YES;
  }

  if (![object isKindOfClass:[FIRBlob class]]) {
    return NO;
  }

  FIRBlob *other = (FIRBlob *)object;
  return self.subtype == other.subtype && [self.bytes isEqualToData:other.bytes];
}

- (NSUInteger)hash {
  return [self.bytes hash] ^ self.subtype;
}

- (id)copyWithZone:(__unused NSZone *_Nullable)zone {
  return [[FIRBlob alloc] initWithBytes:self.bytes subtype:self.subtype isBSON:self.isBSON];
}

- (NSComparisonResult)compare:(FIRBlob *)other {
  if (self.subtype < other.subtype) {
    return NSOrderedAscending;
  } else if (self.subtype > other.subtype) {
    return NSOrderedDescending;
  }

  NSUInteger selfLength = self.bytes.length;
  NSUInteger otherLength = other.bytes.length;
  NSUInteger minLength = MIN(selfLength, otherLength);
  int cmp = memcmp(self.bytes.bytes, other.bytes.bytes, minLength);
  if (cmp < 0) {
    return NSOrderedAscending;
  } else if (cmp > 0) {
    return NSOrderedDescending;
  }

  if (selfLength < otherLength) {
    return NSOrderedAscending;
  } else if (selfLength > otherLength) {
    return NSOrderedDescending;
  }
  return NSOrderedSame;
}

- (NSString *)description {
  return [NSString stringWithFormat:@"<FIRBlob: isBSON:%@, subtype:%u, bytes:%@>",
                                    self.isBSON ? @"YES" : @"NO", (unsigned int)self.subtype,
                                    self.bytes];
}

@end
