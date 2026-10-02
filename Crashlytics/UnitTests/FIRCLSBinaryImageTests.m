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

#include "Crashlytics/Crashlytics/Components/FIRCLSBinaryImage.h"

#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>

#include "Crashlytics/Crashlytics/Helpers/FIRCLSFile.h"

@interface FIRCLSBinaryImageTests : XCTestCase

@end

@implementation FIRCLSBinaryImageTests

- (void)testRecordMainExecutableIncludesMinimumAndBuiltSDKVersions {
  // The test host is built with a current toolchain and deployment target, so its versions are
  // described by LC_BUILD_VERSION rather than LC_VERSION_MIN_*.
  NSString *path =
      [NSTemporaryDirectory() stringByAppendingPathComponent:@"executable_test.clsrecord"];
  [[NSFileManager defaultManager] removeItemAtPath:path error:nil];

  FIRCLSFile file;
  XCTAssertTrue(FIRCLSFileInitWithPath(&file, [path fileSystemRepresentation], false));
  XCTAssertTrue(FIRCLSBinaryImageRecordMainExecutable(&file));
  FIRCLSFileClose(&file);

  NSData *data = [NSData dataWithContentsOfFile:path];
  XCTAssertNotNil(data);
  if (!data) {
    return;
  }

  NSDictionary *record = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
  NSDictionary *executable = record[@"executable"];
  XCTAssertNotNil(executable);

  XCTAssertNotNil(executable[@"minimum_sdk_version"]);
  XCTAssertNotNil(executable[@"built_sdk_version"]);
  XCTAssertNotEqualObjects(executable[@"minimum_sdk_version"], @"0.0.0");
  XCTAssertNotEqualObjects(executable[@"built_sdk_version"], @"0.0.0");

  [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
}

@end
