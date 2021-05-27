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

#import "FirebasePerformance/Sources/Common/FPRConsoleURLGenerator.h"

@interface FPRConsoleURLGeneratorTest : XCTestCase

@end

@implementation FPRConsoleURLGeneratorTest

static NSString *const PROJECT_ID = @"test-project";
static NSString *const BUNDLE_ID = @"test-bundle";
static NSString *const TRACE_NAME = @"test-trace";

/** Tests that the dashboard URL is correctly generated. */
- (void)testDashboardURL {
  NSString *url = [FPRConsoleURLGenerator generateDashboardURLWithProjectID:PROJECT_ID
                                                                   bundleID:BUNDLE_ID];
  NSString *expectedURL = @"https://console.firebase.google.com/project/test-project/performance/"
                          @"app/ios:test-bundle/trends?utm_source=perf-ios-sdk&utm_medium=ios-ide";
  XCTAssertEqualObjects(url, expectedURL);
}

/** Tests that the custom trace URL is correctly generated. */
- (void)testCustomTraceURL {
  NSString *url = [FPRConsoleURLGenerator generateCustomTraceURLWithProjectID:PROJECT_ID
                                                                     bundleID:BUNDLE_ID
                                                                    traceName:TRACE_NAME];
  NSString *expectedURL =
      @"https://console.firebase.google.com/project/test-project/performance/app/ios:test-bundle/"
      @"metrics/trace/DURATION_TRACE/test-trace?utm_source=perf-ios-sdk&utm_medium=ios-ide";
  XCTAssertEqualObjects(url, expectedURL);
}

/** Tests that the screen trace URL is correctly generated. */
- (void)testScreenTraceURL {
  NSString *url = [FPRConsoleURLGenerator generateScreenTraceURLWithProjectID:PROJECT_ID
                                                                     bundleID:BUNDLE_ID
                                                                    traceName:TRACE_NAME];
  NSString *expectedURL =
      @"https://console.firebase.google.com/project/test-project/performance/app/ios:test-bundle/"
      @"metrics/trace/SCREEN_TRACE/test-trace?utm_source=perf-ios-sdk&utm_medium=ios-ide";
  XCTAssertEqualObjects(url, expectedURL);
}

@end
