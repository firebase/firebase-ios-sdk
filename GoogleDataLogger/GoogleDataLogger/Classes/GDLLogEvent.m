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

#import <GoogleDataLogger/GDLLogEvent.h>

#import "GDLLogEvent_Private.h"

@implementation GDLLogEvent

- (instancetype)initWithLogMapID:(NSString *)logMapID logTarget:(NSInteger)logTarget {
  NSAssert(logMapID.length > 0, @"Please give a valid log map ID");
  NSAssert(logTarget > 0, @"A log target cannot be negative or 0");
  self = [super init];
  if (self) {
    _logMapID = logMapID;
    _logTarget = logTarget;
  }
  return self;
}

- (instancetype)copy {
  GDLLogEvent *copy = [[GDLLogEvent alloc] initWithLogMapID:_logMapID logTarget:_logTarget];
  copy.extension = _extension;
  copy.extensionBytes = _extensionBytes;
  copy.qosTier = _qosTier;
  copy.clockSnapshot = _clockSnapshot;
  return copy;
}

- (NSUInteger)hash {
  // This loses some precision, but it's probably fine.
  NSUInteger timeHash = (NSUInteger)(_clockSnapshot.timeMillis ^ _clockSnapshot.uptimeMillis);
  return [_logMapID hash] ^ _logTarget ^ [_extensionBytes hash] ^ _qosTier ^ timeHash;
}

- (void)setExtension:(id<GDLLogProto>)extension {
  if (extension != _extension) {
    _extension = extension;
    _extensionBytes = [extension protoBytes];
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

/** NSCoding key for clockSnapshot.timeMillis property. */
static NSString *clockSnapshotTimeMillisKey = @"_clockSnapshotTimeMillis";

/** NSCoding key for clockSnapshot.uptimeMillis property. */
static NSString *clockSnapshotUpTimeMillis = @"_clockSnapshotUpTimeMillis";

/** NSCoding key for clockSnapshot.timezoneOffsetMillis property. */
static NSString *clockSnapshotTimezoneOffsetMillis = @"_clockSnapshotTimezoneOffsetMillis";

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
    _clockSnapshot.timeMillis = [aDecoder decodeInt64ForKey:clockSnapshotTimeMillisKey];
    _clockSnapshot.uptimeMillis = [aDecoder decodeInt64ForKey:clockSnapshotUpTimeMillis];
    _clockSnapshot.timezoneOffsetMillis =
        [aDecoder decodeInt64ForKey:clockSnapshotTimezoneOffsetMillis];
  }
  return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
  [aCoder encodeObject:_logMapID forKey:logMapIDKey];
  [aCoder encodeInteger:_logTarget forKey:logTargetKey];
  [aCoder encodeObject:_extensionBytes forKey:extensionBytesKey];
  [aCoder encodeInteger:_qosTier forKey:qosTierKey];
  [aCoder encodeInt64:_clockSnapshot.timeMillis forKey:clockSnapshotTimeMillisKey];
  [aCoder encodeInt64:_clockSnapshot.uptimeMillis forKey:clockSnapshotUpTimeMillis];
  [aCoder encodeInt64:_clockSnapshot.timezoneOffsetMillis forKey:clockSnapshotTimezoneOffsetMillis];
}

@end
