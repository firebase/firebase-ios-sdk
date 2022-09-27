/*
 * Copyright 2022 Google LLC
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

#import "FIRAggregateQuerySnapshot+Internal.h"

#import "FIRAggregateQuery.h"

NS_ASSUME_NONNULL_BEGIN

@implementation FIRAggregateQuerySnapshot {
  int64_t _result;
  FIRAggregateQuery* _query;
}

- (instancetype)initWithCount:(int64_t)count query:(FIRAggregateQuery*)query {
  if (self = [super init]) {
    _result = count;
    _query = query;
  }
  return self;
}

#pragma mark - NSObject Methods

- (BOOL)isEqual:(nullable id)other {
  if (other == self) return YES;
  if (![[other class] isEqual:[self class]]) return NO;

  auto otherSnap = static_cast<FIRAggregateQuerySnapshot*>(other);
  return _result == otherSnap->_result && [_query isEqual:otherSnap->_query];
}

- (NSUInteger)hash {
  NSUInteger result = [_query hash];
  result = 31 * result + [[self count] hash];
  return result;
}

#pragma mark - Public Methods

- (NSNumber*)count {
  return [NSNumber numberWithLongLong:_result];
}

- (FIRAggregateQuery*)query {
  return _query;
}

@end

NS_ASSUME_NONNULL_END
