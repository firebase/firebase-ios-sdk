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

#include "Firestore/Source/Public/FirebaseFirestore/FIRVectorValue.h"

NS_ASSUME_NONNULL_BEGIN

@implementation FIRVectorValue

- (instancetype)initWithArray:(NSArray<NSNumber *> *)array {
  if (self = [super init]) {
    _array = [array valueForKey:@"doubleValue"];
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

  return [self.array isEqualToArray:otherVector.array];
}

@end

NS_ASSUME_NONNULL_END
