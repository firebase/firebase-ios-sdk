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

#import "Firestore/Source/Remote/FSTExistenceFilter.h"

@interface FSTExistenceFilter ()

- (instancetype)initWithCount:(int32_t)count NS_DESIGNATED_INITIALIZER;

@end

@implementation FSTExistenceFilter

+ (instancetype)filterWithCount:(int32_t)count {
  return [[FSTExistenceFilter alloc] initWithCount:count];
}

- (instancetype)initWithCount:(int32_t)count {
  if (self = [super init]) {
    _count = count;
  }
  return self;
}

- (BOOL)isEqual:(id)other {
  if (other == self) {
    return YES;
  }
  if (![other isMemberOfClass:[FSTExistenceFilter class]]) {
    return NO;
  }

  return _count == ((FSTExistenceFilter *)other).count;
}

- (NSUInteger)hash {
  return _count;
}

@end
