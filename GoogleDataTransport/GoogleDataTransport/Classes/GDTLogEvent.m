/*
 * Copyright 2018 Google
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

#import <GoogleDataTransport/GDTLogEvent.h>

#import "GDTAssert.h"
#import "GDTLogEvent_Private.h"

@implementation GDTLogEvent

- (instancetype)initWithLogMapID:(NSString *)logMapID logTarget:(NSInteger)logTarget {
  GDTAssert(logMapID.length > 0, @"Please give a valid log map ID");
  GDTAssert(logTarget > 0, @"A log target cannot be negative or 0");
  self = [super init];
  if (self) {
    _logMapID = logMapID;
    _logTarget = logTarget;
    _qosTier = GDTLogQosDefault;
  }
  return self;
}

- (instancetype)copy {
  GDTLogEvent *copy = [[GDTLogEvent alloc] initWithLogMapID:_logMapID logTarget:_logTarget];
  copy.extension = _extension;
  copy.extensionBytes = _extensionBytes;
  copy.qosTier = _qosTier;
  copy.clockSnapshot = _clockSnapshot;
  copy.customPrioritizationParams = _customPrioritizationParams;
  return copy;
}

- (NSUInteger)hash {
  // This loses some precision, but it's probably fine.
  NSUInteger logMapIDHash = [_logMapID hash];
  NSUInteger timeHash = [_clockSnapshot hash];
  NSUInteger extensionBytesHash = [_extensionBytes hash];
  return logMapIDHash ^ _logTarget ^ extensionBytesHash ^ _qosTier ^ timeHash;
}

- (void)setExtension:(id<GDTLogProto>)extension {
  // If you're looking here because of a performance issue in -transportBytes slowing the assignment
  // of extension, one way to address this is to add a queue to this class,
  // dispatch_(barrier_ if concurrent)async here, and implement the getter with a dispatch_sync.
  if (extension != _extension) {
    _extension = extension;
    _extensionBytes = [extension transportBytes];
  }
}

#pragma mark - NSSecureCoding and NSCoding Protocols

/** NSCoding key for logMapID property. */
static NSString *logMapIDKey = @"_logMapID";

/** NSCoding key for logTarget property. */
static NSString *logTargetKey = @"_logTarget";

/** NSCoding key for extensionBytes property. */
static NSString *extensionBytesKey = @"_extensionBytes";

/** NSCoding key for qosTier property. */
static NSString *qosTierKey = @"_qosTier";

/** NSCoding key for clockSnapshot property. */
static NSString *clockSnapshotKey = @"_clockSnapshot";

+ (BOOL)supportsSecureCoding {
  return YES;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
  NSString *logMapID = [aDecoder decodeObjectOfClass:[NSObject class] forKey:logMapIDKey];
  NSInteger logTarget = [aDecoder decodeIntegerForKey:logTargetKey];
  self = [self initWithLogMapID:logMapID logTarget:logTarget];
  if (self) {
    _extensionBytes = [aDecoder decodeObjectOfClass:[NSData class] forKey:extensionBytesKey];
    _qosTier = [aDecoder decodeIntegerForKey:qosTierKey];
    _clockSnapshot = [aDecoder decodeObjectOfClass:[GDTClock class] forKey:clockSnapshotKey];
  }
  return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
  [aCoder encodeObject:_logMapID forKey:logMapIDKey];
  [aCoder encodeInteger:_logTarget forKey:logTargetKey];
  [aCoder encodeObject:_extensionBytes forKey:extensionBytesKey];
  [aCoder encodeInteger:_qosTier forKey:qosTierKey];
  [aCoder encodeObject:_clockSnapshot forKey:clockSnapshotKey];
}

@end
