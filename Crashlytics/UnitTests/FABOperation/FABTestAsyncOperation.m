// Copyright 2019 Google
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import "Crashlytics/UnitTests/FABOperation/FABTestAsyncOperation.h"

const NSUInteger FABTestAsyncOperationErrorCodeCancelled = 12345;

@implementation FABTestAsyncOperation

- (void)main {
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)),
                 dispatch_get_main_queue(), ^{
                   [self finishWork];
                 });
}

- (void)finishWork {
  if (self.asyncCompletion) {
    NSError *error;
    if (self.isCancelled) {
      error = [NSError errorWithDomain:@"com.FABInFlightCancellationTests.error-domain"
                                  code:FABTestAsyncOperationErrorCodeCancelled
                              userInfo:@{
                                NSLocalizedDescriptionKey :
                                    [NSString stringWithFormat:@"%@ cancelled", self.name]
                              }];
    }
    [self finishWithError:error];
  }
}

@end
