/*
 * Copyright 2021 Google LLC
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

#import "FirebaseAppCheck/Sources/Core/Backoff/FIRAppCheckBackoffWrapper.h"

NS_ASSUME_NONNULL_BEGIN

@interface FIRAppCheckBackoffWrapper ()

@property(nonatomic, readonly) FIRAppCheckDateProvider dateProvider;

@end

@implementation FIRAppCheckBackoffWrapper

- (instancetype)init {
  return [self initWithDateProvider:[FIRAppCheckBackoffWrapper currentDateProvider]];
}

- (instancetype)initWithDateProvider:(FIRAppCheckDateProvider)dateProvider {
  self = [super init];
  if (self) {
    _dateProvider = [dateProvider copy];
  }
  return self;
}

+ (FIRAppCheckDateProvider)currentDateProvider {
  return ^NSDate *(void) {
    return [NSDate date];
  };
}

- (FBLPromise *)backoff:(FIRAppCheckBackoffOperationProvider)operationProvider
           errorHandler:(FIRAppCheckBackoffErrorHandler)errorHandler {
  return operationProvider();
}

- (FIRAppCheckBackoffErrorHandler)defaultErrorHandler {
  return ^FIRAppCheckBackoffType(NSError *error) {
    return FIRAppCheckBackoffTypeNone;
  };
}

- (void)resetBackoff {
  // TODO: Implement.
}

@end

NS_ASSUME_NONNULL_END
