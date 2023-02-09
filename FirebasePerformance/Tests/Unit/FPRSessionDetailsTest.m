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

#import <XCTest/XCTest.h>

#import "FirebasePerformance/Sources/AppActivity/FPRSessionDetails.h"

@interface FPRSessionDetailsTest : XCTestCase

@end

@implementation FPRSessionDetailsTest

/** Validates that an instance gets created. */
- (void)testInstanceCreation {
  FPRSessionDetails *details = [[FPRSessionDetails alloc] initWithSessionId:@"random"
                                                                    options:FPRSessionOptionsNone];
  XCTAssertNotNil(details);
}

/** Validates object copy contains same details as the source. */
- (void)testInstanceCopy {
  FPRSessionDetails *details = [[FPRSessionDetails alloc] initWithSessionId:@"random"
                                                                    options:FPRSessionOptionsNone];
  FPRSessionDetails *detailsCopy = [details copy];
  NSDate *now = [NSDate date];
  XCTAssertEqual(details.sessionId, detailsCopy.sessionId);
  XCTAssertEqual(details.options, detailsCopy.options);
  XCTAssertEqual([details sessionLengthInMinutesFromDate:now],
                 [detailsCopy sessionLengthInMinutesFromDate:now]);
  XCTAssertNotNil(details);
}

/** Validated that the details are valid. */
- (void)testDetailsData {
  FPRSessionDetails *details = [[FPRSessionDetails alloc] initWithSessionId:@"random"
                                                                    options:FPRSessionOptionsNone];
  XCTAssertEqual(details.sessionId, @"random");
  XCTAssertEqual(details.options, FPRSessionOptionsNone);
  XCTAssertEqual([details sessionLengthInMinutesFromDate:[NSDate date]], 0);
}

/** Validates that the session details equality with another object. */
- (void)testSessionDetailsEquality {
  FPRSessionDetails *details1 = [[FPRSessionDetails alloc] initWithSessionId:@"random"
                                                                     options:FPRSessionOptionsNone];
  FPRSessionDetails *details2 = [[FPRSessionDetails alloc] initWithSessionId:@"random"
                                                                     options:FPRSessionOptionsNone];
  XCTAssertEqualObjects(details1, details2);

  FPRSessionDetails *details3 =
      [[FPRSessionDetails alloc] initWithSessionId:@"random" options:FPRSessionOptionsEvents];
  XCTAssertEqualObjects(details1, details3);
}

@end
