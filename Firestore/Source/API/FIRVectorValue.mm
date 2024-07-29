/*
 * Copyright 2024 Google LLC
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

#import <Foundation/Foundation.h>

#include <vector>

#include "Firestore/Source/Public/FirebaseFirestore/FIRVectorValue.h"

NS_ASSUME_NONNULL_BEGIN

@interface FIRVectorValue () {
  /** Internal vector representation */
  std::vector<double> _internalValue;
}

@end

@implementation FIRVectorValue

- (NSArray<NSNumber *> *) array {
    size_t length = _internalValue.size();
    NSMutableArray<NSNumber *> *outArray =
        [[NSMutableArray<NSNumber *> alloc] initWithCapacity:length];
    for (size_t i = 0; i < length; i++) {
      [outArray addObject:[[NSNumber alloc] initWithDouble:self->_internalValue.at(i)]];
    }

    return outArray;
}

- (instancetype)initWithArray:(NSArray<NSNumber *> *)data {
  if (self = [super init]) {
    std::vector<double> converted;
    converted.reserve(data.count);
    for (NSNumber *value in data) {
      converted.emplace_back([value doubleValue]);
    }

    _internalValue = std::move(converted);
  }
  return self;
}

- (BOOL)isEqual:(nullable id)object {
  if (self == object) {
    return YES;
  }

  if (![object isKindOfClass:[FIRVectorValue class]]) {
    return NO;
  }

  FIRVectorValue *otherVector = ((FIRVectorValue *)object);

  if (self->_internalValue.size() != otherVector->_internalValue.size()) {
    return NO;
  }

  for (size_t i = 0; i < self->_internalValue.size(); i++) {
    if (self->_internalValue[i] != otherVector->_internalValue[i]) return NO;
  }

  return YES;
}

@end

NS_ASSUME_NONNULL_END
