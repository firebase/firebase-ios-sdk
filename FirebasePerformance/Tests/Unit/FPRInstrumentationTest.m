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

#import "FirebasePerformance/Sources/Instrumentation/FPRInstrumentation.h"
#import "FirebasePerformance/Sources/Instrumentation/Network/FPRNSURLSessionInstrument.h"

#import <OCMock/OCMock.h>

@interface FPRInstrumentationTest : XCTestCase

@end

@implementation FPRInstrumentationTest

- (void)setUp {
  id FPRNSURLSessionClassMock = OCMClassMock([FPRNSURLSessionInstrument class]);
  OCMStub([FPRNSURLSessionClassMock alloc]).andReturn(FPRNSURLSessionClassMock);
}

- (void)testInit {
  FPRInstrumentation *instrumentation = [[FPRInstrumentation alloc] init];
  XCTAssertNotNil(instrumentation);
}

#pragma mark - Unswizzle based tests

#ifndef SWIFT_PACKAGE

- (void)testRegisterInstrumentGroup {
  FPRInstrumentation *instrumentation = [[FPRInstrumentation alloc] init];
  NSUInteger numberOfInstrumentsInGroup =
      [instrumentation registerInstrumentGroup:kFPRInstrumentationGroupNetworkKey];
  XCTAssertGreaterThan(numberOfInstrumentsInGroup, 0);
  [instrumentation deregisterInstrumentGroup:kFPRInstrumentationGroupNetworkKey];
}

- (void)testDeregisterInstrumentGroup {
  FPRInstrumentation *instrumentation = [[FPRInstrumentation alloc] init];
  [instrumentation registerInstrumentGroup:kFPRInstrumentationGroupNetworkKey];
  XCTAssertTrue([instrumentation deregisterInstrumentGroup:kFPRInstrumentationGroupNetworkKey]);
}

#endif  // SWIFT_PACKAGE

@end
