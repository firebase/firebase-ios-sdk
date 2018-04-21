// Copyright 2018 Google
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

#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>

#import <FirebaseCore/FIRAppEnvironmentUtil.h>

#import "FIRTestCase.h"

@interface FIRAppEnvironmentUtilTest : FIRTestCase

@property(nonatomic) id processInfoMock;

@end

@implementation FIRAppEnvironmentUtilTest

- (void)setUp {
  [super setUp];

  _processInfoMock = OCMPartialMock([NSProcessInfo processInfo]);
}

- (void)tearDown {
  [super tearDown];

  [_processInfoMock stopMocking];
}

- (void)testSystemVersionInfoMajorOnly {
  NSOperatingSystemVersion osTen = {.majorVersion = 10, .minorVersion = 0, .patchVersion = 0};
  OCMStub([self.processInfoMock operatingSystemVersion]).andReturn(osTen);

  XCTAssertTrue([[FIRAppEnvironmentUtil systemVersion] isEqualToString:@"10.0"]);
}

- (void)testSystemVersionInfoMajorMinor {
  NSOperatingSystemVersion osTenTwo = {.majorVersion = 10, .minorVersion = 2, .patchVersion = 0};
  OCMStub([self.processInfoMock operatingSystemVersion]).andReturn(osTenTwo);

  XCTAssertTrue([[FIRAppEnvironmentUtil systemVersion] isEqualToString:@"10.2"]);
}

- (void)testSystemVersionInfoMajorMinorPatch {
  NSOperatingSystemVersion osTenTwoOne = {.majorVersion = 10, .minorVersion = 2, .patchVersion = 1};
  OCMStub([self.processInfoMock operatingSystemVersion]).andReturn(osTenTwoOne);

  XCTAssertTrue([[FIRAppEnvironmentUtil systemVersion] isEqualToString:@"10.2.1"]);
}

@end
