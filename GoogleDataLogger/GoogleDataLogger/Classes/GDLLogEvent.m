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

#import "GDLLogEvent.h"

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

#pragma mark - NSSecureCoding and NSCoding Protocols

+ (BOOL)supportsSecureCoding {
  return YES;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
  NSString *logMapID = [aDecoder decodeObjectOfClass:[NSObject class] forKey:@"_logMapID"];
  NSInteger logTarget = [aDecoder decodeIntegerForKey:@"_logTarget"];
  self = [self initWithLogMapID:logMapID logTarget:logTarget];
  if (self) {
    _extensionData = [aDecoder decodeObjectOfClass:[NSData class] forKey:@"_extensionData"];
    _qosTier = [aDecoder decodeIntegerForKey:@"_qosTier"];
    _clockSnapshot.timeMillis = [aDecoder decodeInt64ForKey:@"clockSnapshotTimeMillis"];
    _clockSnapshot.uptimeMillis = [aDecoder decodeInt64ForKey:@"clockSnapshotUpTimeMillis"];
    _clockSnapshot.timezoneOffsetMillis =
        [aDecoder decodeInt64ForKey:@"clockSnapshotTimezoneOffsetMillis"];
  }
  return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
  [aCoder encodeObject:_logMapID forKey:@"_logMapID"];
  [aCoder encodeInteger:_logTarget forKey:@"_logTarget"];
  [aCoder encodeObject:_extensionData forKey:@"_extensionData"];
  [aCoder encodeInteger:_qosTier forKey:@"_qosTier"];
  [aCoder encodeInt64:_clockSnapshot.timeMillis forKey:@"clockSnapshotTimeMillis"];
  [aCoder encodeInt64:_clockSnapshot.uptimeMillis forKey:@"clockSnapshotUpTimeMillis"];
  [aCoder encodeInt64:_clockSnapshot.timezoneOffsetMillis
               forKey:@"clockSnapshotTimezoneOffsetMillis"];
}

@end
