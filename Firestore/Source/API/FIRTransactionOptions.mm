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

#import "FIRTransactionOptions.h"
#import "FIRTransactionOptions+Internal.h"

#import <Foundation/Foundation.h>

#include <cstdint>
#include <string>

#include "Firestore/core/src/api/firestore.h"
#include "Firestore/core/src/util/exception.h"

NS_ASSUME_NONNULL_BEGIN

using firebase::firestore::api::kDefaultTransactionMaxAttempts;
using firebase::firestore::util::ThrowInvalidArgument;

@implementation FIRTransactionOptions

- (instancetype)init {
  if (self = [super init]) {
    _maxAttempts = [[self class] defaultMaxAttempts];
  }
  return self;
}

+ (int)defaultMaxAttempts {
  return kDefaultTransactionMaxAttempts;
}

- (BOOL)isEqual:(id)other {
  if (self == other) {
    return YES;
  } else if (![other isKindOfClass:[FIRTransactionOptions class]]) {
    return NO;
  }

  FIRTransactionOptions *otherOptions = (FIRTransactionOptions *)other;
  return self.maxAttempts == otherOptions.maxAttempts;
}

- (NSUInteger)hash {
  return _maxAttempts * 31;
}

- (id)copyWithZone:(__unused NSZone *_Nullable)zone {
  FIRTransactionOptions *copy = [[FIRTransactionOptions alloc] init];
  copy.maxAttempts = self.maxAttempts;
  return copy;
}

- (void)setMaxAttempts:(NSInteger)maxAttempts {
  if (maxAttempts <= 0 || maxAttempts > INT32_MAX) {
    ThrowInvalidArgument("Invalid maxAttempts: %s", std::to_string(maxAttempts));
  }
  _maxAttempts = maxAttempts;
}

@end

NS_ASSUME_NONNULL_END
