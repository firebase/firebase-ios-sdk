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

#import "Firestore/Source/API/FIRTimestamp+Internal.h"

#include "Firestore/core/src/firebase/firestore/util/comparison.h"

#import "Firestore/Source/Util/FSTAssert.h"

using firebase::firestore::util::WrapCompare;

NS_ASSUME_NONNULL_BEGIN

static const int kNanosPerSecond = 1000000;

@implementation FIRTimestamp (Internal)

#pragma mark - Internal constructors

+ (instancetype)timestamp {
  return [FIRTimestamp timestampWithDate:[NSDate date]];
}

#pragma mark - Internal public methods

- (NSComparisonResult)compare:(FIRTimestamp *)other {
  NSComparisonResult result = WrapCompare<int64_t>(self.seconds, other.seconds);
  if (result != NSOrderedSame) {
    return result;
  }
  return WrapCompare<int32_t>(self.nanoseconds, other.nanoseconds);
}

- (NSString *)ISO8601String {
  NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
  formatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss";
  formatter.timeZone = [NSTimeZone timeZoneWithName:@"UTC"];
  NSDate *secondsDate = [NSDate dateWithTimeIntervalSince1970:self.seconds];
  NSString *secondsString = [formatter stringFromDate:secondsDate];
  FSTAssert(secondsString.length == 19, @"Invalid ISO string: %@", secondsString);

  NSString *nanosString = [NSString stringWithFormat:@"%09d", self.nanoseconds];
  return [NSString stringWithFormat:@"%@.%@Z", secondsString, nanosString];
}

@end

@implementation FIRTimestamp

#pragma mark - Constructors

+ (instancetype)timestampWithDate:(NSDate *)date {
  double secondsDouble;
  double fraction = modf(date.timeIntervalSince1970, &secondsDouble);
  // GCP Timestamps always have non-negative nanos.
  if (fraction < 0) {
    fraction += 1.0;
    secondsDouble -= 1.0;
  }
  int64_t seconds = (int64_t)secondsDouble;
  int32_t nanos = (int32_t)(fraction * kNanosPerSecond);
  return [[FIRTimestamp alloc] initWithSeconds:seconds nanoseconds:nanos];
}

+ (instancetype)timestampWithSeconds:(int64_t)seconds nanoseconds:(int32_t)nanoseconds {
  return [[FIRTimestamp alloc] initWithSeconds:seconds nanoseconds:nanoseconds];
}

- (instancetype)initWithSeconds:(int64_t)seconds nanoseconds:(int32_t)nanoseconds {
  self = [super init];
  if (self) {
    FSTAssert(nanoseconds >= 0, @"timestamp nanoseconds out of range: %d", nanoseconds);
    FSTAssert(nanoseconds < 1e9, @"timestamp nanoseconds out of range: %d", nanoseconds);
    // Midnight at the beginning of 1/1/1 is the earliest timestamp Firestore supports.
    FSTAssert(seconds >= -62135596800L, @"timestamp seconds out of range: %lld", seconds);
    // This will break in the year 10,000.
    FSTAssert(seconds < 253402300800L, @"timestamp seconds out of range: %lld", seconds);

    _seconds = seconds;
    _nanoseconds = nanoseconds;
  }
  return self;
}

#pragma mark - NSObject methods

- (BOOL)isEqual:(id)object {
  if (self == object) {
    return YES;
  }
  if (![object isKindOfClass:[FIRTimestamp class]]) {
    return NO;
  }
  return [self isEqualToTimestamp:(FIRTimestamp *)object];
}

- (NSUInteger)hash {
  return (NSUInteger)((self.seconds >> 32) ^ self.seconds ^ self.nanoseconds);
}

- (NSString *)description {
  return [NSString stringWithFormat:@"FIRTimestamp: seconds=%lld nanoseconds=%d>", self.seconds,
                                    self.nanoseconds];
}

/** Implements NSCopying without actually copying because timestamps are immutable. */
- (id)copyWithZone:(NSZone *_Nullable)zone {
  return self;
}

#pragma mark - Public methods

- (NSDate *)approximateDateValue {
  NSTimeInterval interval = (NSTimeInterval)self.seconds + ((NSTimeInterval)self.nanoseconds) / 1e9;
  return [NSDate dateWithTimeIntervalSince1970:interval];
}

#pragma mark - Private methods

- (BOOL)isEqualToTimestamp:(FIRTimestamp *)other {
  return [self compare:other] == NSOrderedSame;
}

@end

NS_ASSUME_NONNULL_END
