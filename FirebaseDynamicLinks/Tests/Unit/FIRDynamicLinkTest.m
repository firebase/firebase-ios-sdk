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

#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>
#import "FirebaseDynamicLinks/Sources/FIRDynamicLink+Private.h"

@interface FIRDynamicLinkTest : XCTestCase {
}
@end

@implementation FIRDynamicLinkTest

NSMutableDictionary<NSString *, NSString *> *fdlParameters = nil;
NSDictionary<NSString *, NSString *> *linkParameters = nil;
NSDictionary<NSString *, NSString *> *utmParameters = nil;

- (void)setUp {
  [super setUp];

  linkParameters = @{
    @"deep_link_id" : @"https://mmaksym.com/test-app1",
    @"match_message" : @"Link is uniquely matched for this device.",
    @"match_type" : @"unique",
    @"a_parameter" : @"a_value"
  };
  utmParameters = @{
    @"utm_campaign" : @"eldhosembabu Test",
    @"utm_medium" : @"test_medium",
    @"utm_source" : @"test_source",
  };

  fdlParameters = [[NSMutableDictionary alloc] initWithDictionary:linkParameters];
  [fdlParameters addEntriesFromDictionary:utmParameters];
}

- (void)testDynamicLinkParameters_InitWithParameters {
  FIRDynamicLink *dynamicLink = [[FIRDynamicLink alloc] initWithParametersDictionary:fdlParameters];
  XCTAssertEqual([fdlParameters count], [[dynamicLink parametersDictionary] count]);
  for (NSString *key in fdlParameters) {
    NSString *expectedValue = [fdlParameters valueForKey:key];
    NSString *derivedValue = [[dynamicLink parametersDictionary] valueForKey:key];
    XCTAssertNotNil(derivedValue, @"Cannot be null!");
    XCTAssertEqualObjects(derivedValue, expectedValue);
  }
}

- (void)testDynamicLinkUtmParameters_InitWithParameters {
  FIRDynamicLink *dynamicLink = [[FIRDynamicLink alloc] initWithParametersDictionary:fdlParameters];
  XCTAssertEqual([[dynamicLink utmParametersDictionary] count], [utmParameters count]);
  for (NSString *key in utmParameters) {
    NSString *expectedValue = [utmParameters valueForKey:key];
    NSString *derivedValue = [[dynamicLink utmParametersDictionary] valueForKey:key];
    XCTAssertNotNil(derivedValue, @"Cannot be null!");
    XCTAssertEqualObjects(derivedValue, expectedValue);
  }
}

- (void)testDynamicLinkParameters_InitWithNoUtmParameters {
  FIRDynamicLink *dynamicLink =
      [[FIRDynamicLink alloc] initWithParametersDictionary:linkParameters];
  XCTAssertEqual([[dynamicLink parametersDictionary] count], [linkParameters count]);
  XCTAssertEqual([[dynamicLink utmParametersDictionary] count], 0);
}

@end
