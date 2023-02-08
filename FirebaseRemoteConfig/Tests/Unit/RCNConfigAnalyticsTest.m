/*
 * Copyright 2019 Google
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

#import <OCMock/OCMock.h>
#import <XCTest/XCTest.h>

// #import "RCNConfigAnalytics.h"

@interface RCNConfigAnalyticsTest : XCTestCase {
  id _mockAnalytics;
  RCNConfigAnalytics *_configAnalytics;
}
@end

@implementation RCNConfigAnalyticsTest

- (void)setUp {
  [super setUp];
  _mockAnalytics = OCMClassMock([FIRAnalytics class]);
  _configAnalytics = [[RCNConfigAnalytics alloc] init];
}

- (void)testFetchUserProperty {
  XCTestExpectation *fetchExpectation =
      [self expectationWithDescription:@"Test fetch user property."];

  // Mocks the user property fetching response.
  OCMStub([_mockAnalytics userPropertiesIncludingInternal:NO
                                                    queue:[OCMArg any]
                                                 callback:([OCMArg invokeBlockWithArgs:@{
                                                   @"user_property_event_name" : @"level up",
                                                   @"user_property_gold_amount" : @"1800",
                                                   @"user_property_level" : @20
                                                 },
                                                                                       nil])]);

  [_configAnalytics fetchUserPropertiesWithCompletionHandler:^(NSDictionary *userProperties) {
    XCTAssertNotNil(userProperties);
    XCTAssertEqual(userProperties.count, 3);
    XCTAssertEqualObjects(@"level up", userProperties[@"user_property_event_name"]);
    XCTAssertEqualObjects(@20, userProperties[@"user_property_level"]);
    XCTAssertEqualObjects(@"1800", userProperties[@"user_property_gold_amount"]);

    [fetchExpectation fulfill];
  }];
  [self waitForExpectationsWithTimeout:1.0
                               handler:^(NSError *error) {
                                 XCTAssertNil(error);
                               }];
}

- (void)testFetchUserPropertyWithEmptyResponse {
  XCTestExpectation *fetchExpectation =
      [self expectationWithDescription:@"Test fetch empty user property."];

  // Mocks the user property fetching response.
  OCMStub([_mockAnalytics userPropertiesIncludingInternal:NO
                                                    queue:[OCMArg any]
                                                 callback:([OCMArg invokeBlockWithArgs:@{}, nil])]);

  // Tests passing nil callback won't crash.
  [_configAnalytics fetchUserPropertiesWithCompletionHandler:nil];

  [_configAnalytics fetchUserPropertiesWithCompletionHandler:^(NSDictionary *userProperties) {
    XCTAssertNotNil(userProperties);
    XCTAssertEqual(userProperties.count, 0);
    [fetchExpectation fulfill];
  }];
  [self waitForExpectationsWithTimeout:1.0
                               handler:^(NSError *error) {
                                 XCTAssertNil(error);
                               }];
}
@end
