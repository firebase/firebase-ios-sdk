// Copyright 2026 Google LLC
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

#import "Crashlytics/Crashlytics/Settings/Models/FIRCLSApplicationIdentifierModel.h"

#import <XCTest/XCTest.h>

@interface FIRCLSApplicationIdentifierModelTests : XCTestCase

@end

@implementation FIRCLSApplicationIdentifierModelTests

- (void)testReadsMinimumAndBuiltSDKVersionsOfExecutable {
  // The test host is built with a current toolchain and deployment target, so its versions are
  // described by LC_BUILD_VERSION rather than LC_VERSION_MIN_*.
  FIRCLSApplicationIdentifierModel *model = [[FIRCLSApplicationIdentifierModel alloc] init];
  XCTAssertNotNil(model);

  XCTAssertNotEqualObjects(model.minimumSDKString, @"0.0.0");
  XCTAssertNotEqualObjects(model.builtSDKString, @"0.0.0");
}

@end
