/*
 * Copyright 2026 Google LLC
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

#import <XCTest/XCTest.h>

#import "FirebaseInAppMessaging/Sources/Analytics/FIRIAMClearcutHttpRequestSender.h"
#import "FirebaseInAppMessaging/Sources/Private/Util/FIRIAMTimeFetcher.h"

@interface FIRIAMClearcutHttpRequestSender (UnitTest)
- (void)handleClearcutAPICallResponseWithData:(NSData *)data
                                     response:(NSURLResponse *)response
                                        error:(NSError *)error
                                   completion:(nonnull void (^)(BOOL success,
                                                                BOOL shouldRetryLogs,
                                                                int64_t waitTimeInMills))completion;
@end

@interface FIRIAMClearcutHttpRequestSenderTests : XCTestCase
@property(nonatomic) FIRIAMClearcutHttpRequestSender *sender;
@property(nonatomic) NSHTTPURLResponse *successResponse;
@end

@implementation FIRIAMClearcutHttpRequestSenderTests

- (void)setUp {
  [super setUp];
  self.sender = [[FIRIAMClearcutHttpRequestSender alloc]
      initWithClearcutHost:@"clearcut.host"
          usingTimeFetcher:[[FIRIAMTimerWithNSDate alloc] init]
        withOSMajorVersion:@"17"];
  self.successResponse =
      [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"https://clearcut.host"]
                                  statusCode:200
                                 HTTPVersion:nil
                                headerFields:nil];
}

// Feeds `body` as a successful clearcut response and returns the wait time that was reported.
- (int64_t)waitTimeForSuccessfulResponseWithBody:(nullable NSString *)body {
  __block BOOL completionCalled = NO;
  __block int64_t reportedWaitTime = -1;
  [self.sender handleClearcutAPICallResponseWithData:[body dataUsingEncoding:NSUTF8StringEncoding]
                                            response:self.successResponse
                                               error:nil
                                          completion:^(BOOL success, BOOL shouldRetryLogs,
                                                       int64_t waitTimeInMills) {
                                            completionCalled = YES;
                                            XCTAssertTrue(success);
                                            XCTAssertFalse(shouldRetryLogs);
                                            reportedWaitTime = waitTimeInMills;
                                          }];
  XCTAssertTrue(completionCalled);
  return reportedWaitTime;
}

- (void)testValidWaitTime {
  XCTAssertEqual(
      5000, [self waitTimeForSuccessfulResponseWithBody:@"{\"next_request_wait_millis\": 5000}"]);
  // int64 values are encoded as strings in the JSON proto format.
  XCTAssertEqual(
      5000,
      [self waitTimeForSuccessfulResponseWithBody:@"{\"next_request_wait_millis\": \"5000\"}"]);
}

- (void)testMalformedResponseBodies {
  NSArray<NSString *> *malformedBodies = @[
    @"", @"not json", @"[1, 2, 3]", @"{}", @"{\"next_request_wait_millis\": null}",
    @"{\"next_request_wait_millis\": [5000]}", @"{\"next_request_wait_millis\": {}}"
  ];
  for (NSString *body in malformedBodies) {
    XCTAssertEqual(0, [self waitTimeForSuccessfulResponseWithBody:body], @"%@", body);
  }
}

- (void)testNilResponseBody {
  XCTAssertEqual(0, [self waitTimeForSuccessfulResponseWithBody:nil]);
}

@end
