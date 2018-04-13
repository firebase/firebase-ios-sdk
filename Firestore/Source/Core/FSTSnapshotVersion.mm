/*
 * Copyright 2017 Google
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

#import "Firestore/Source/Core/FSTSnapshotVersion.h"

#import "FIRTimestamp.h"

NS_ASSUME_NONNULL_BEGIN

@implementation FSTSnapshotVersion

+ (instancetype)noVersion {
  static FSTSnapshotVersion *min;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    FIRTimestamp *timestamp = [[FIRTimestamp alloc] initWithSeconds:0 nanoseconds:0];
    min = [FSTSnapshotVersion versionWithTimestamp:timestamp];
  });
  return min;
}

+ (instancetype)versionWithTimestamp:(FIRTimestamp *)timestamp {
  return [[FSTSnapshotVersion alloc] initWithTimestamp:timestamp];
}

- (instancetype)initWithTimestamp:(FIRTimestamp *)timestamp {
  self = [super init];
  if (self) {
    _timestamp = timestamp;
  }
  return self;
}

#pragma mark - NSObject methods

- (BOOL)isEqual:(id)object {
  if (self == object) {
    return YES;
  }
  if (![object isKindOfClass:[FSTSnapshotVersion class]]) {
    return NO;
  }
  return [self.timestamp isEqual:((FSTSnapshotVersion *)object).timestamp];
}

- (NSUInteger)hash {
  return self.timestamp.hash;
}

- (NSString *)description {
  return [NSString stringWithFormat:@"<FSTSnapshotVersion: %@>", self.timestamp];
}

- (id)copyWithZone:(NSZone *_Nullable)zone {
  // Implements NSCopying without actually copying because timestamps are immutable.
  return self;
}

#pragma mark - Public methods

- (NSComparisonResult)compare:(FSTSnapshotVersion *)other {
  return [self.timestamp compare:other.timestamp];
}

@end

NS_ASSUME_NONNULL_END
