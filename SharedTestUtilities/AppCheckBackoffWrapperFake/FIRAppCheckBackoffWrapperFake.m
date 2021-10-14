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

#import "SharedTestUtilities/AppCheckBackoffWrapperFake/FIRAppCheckBackoffWrapperFake.h"

#if __has_include(<FBLPromises/FBLPromises.h>)
#import <FBLPromises/FBLPromises.h>
#else
#import "FBLPromises.h"
#endif

NS_ASSUME_NONNULL_BEGIN

@implementation FIRAppCheckBackoffWrapperFake

- (FBLPromise *)applyBackoffToOperation:(FIRAppCheckBackoffOperationProvider)operationProvider
                           errorHandler:(FIRAppCheckBackoffErrorHandler)errorHandler {
  [self.backoffExpectation fulfill];

  if (self.isNextOperationAllowed) {
    return operationProvider()
        .then(^id(id value) {
          self->_operationResult = value;
          self->_operationError = nil;
          return value;
        })
        .recover(^id(NSError *error) {
          self->_operationError = error;
          self->_operationResult = nil;

          errorHandler(error);

          return error;
        });
  } else {
    FBLPromise *rejectedPromise = [FBLPromise pendingPromise];
    [rejectedPromise reject:self.backoffError];
    return rejectedPromise;
  }
}

- (FIRAppCheckBackoffErrorHandler)defaultAppCheckProviderErrorHandler {
  if (_defaultErrorHandler) {
    return _defaultErrorHandler;
  }

  return ^FIRAppCheckBackoffType(NSError *error) {
    return FIRAppCheckBackoffTypeNone;
  };
}

- (NSError *)backoffError {
  return [NSError errorWithDomain:@"FIRAppCheckBackoffWrapperFake.backoff" code:-1 userInfo:nil];
}

@end

NS_ASSUME_NONNULL_END
