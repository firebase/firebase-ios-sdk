// Copyright 2020 Google LLC
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

// Non-google3 relative import to support building with Xcode.
#import "PerfFuzzNSURLSession.h"
#import "PerfNetworkConnection+Protected.h"

@interface PerfFuzzNSURLSession ()

@property(nonatomic, copy) NSString *urlString;

@end

@implementation PerfFuzzNSURLSession

#pragma mark - NetworkConnection

- (void)makeNetworkRequestWithSuccessCallback:(SuccessNetworkCallback)success
                              failureCallback:(FailureNetworkCallback)fail {
  [self logOperationStart];
  NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:self.urlString]];
  NSURLSession *session = nil;
  int numberToFuzz = 1000;
  for (int i = 0; i < numberToFuzz; i++) {
    NSURLSessionConfiguration *configuration = nil;
    BOOL isShared = NO;

    switch (arc4random_uniform(5)) {
      case 0:
        configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
        session = [NSURLSession sessionWithConfiguration:configuration];
        break;
      case 1:
        configuration = [NSURLSessionConfiguration ephemeralSessionConfiguration];
        session = [NSURLSession sessionWithConfiguration:configuration];
        break;
      case 2:
        configuration = [NSURLSessionConfiguration
            backgroundSessionConfiguration:[NSString stringWithFormat:@"fpr_%d", i]];
        session = [NSURLSession sessionWithConfiguration:configuration];
        break;
      case 3:
        configuration = [NSURLSessionConfiguration
            backgroundSessionConfigurationWithIdentifier:[NSString stringWithFormat:@"fpr_%d", i]];
        session = [NSURLSession sessionWithConfiguration:configuration];
        break;
      case 4:
        session = [NSURLSession sharedSession];
        isShared = YES;
        break;
      default:
        break;
    }

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
      NSURLSessionDataTask *task = [session dataTaskWithRequest:request];
      // Intentionally only resume half. The SDK should gracefully handle non-resumed tasks.
      if (i % 2 == 0) {
        [task resume];
      } else {
        [task cancel];
      }
      if (!isShared) {
        [session finishTasksAndInvalidate];
      }
    });
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
  }
  success();
  [self logOperationSuccess];
}

@end
