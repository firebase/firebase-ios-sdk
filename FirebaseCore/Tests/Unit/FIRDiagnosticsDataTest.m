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

#import <XCTest/XCTest.h>

#import "FirebaseCore/Sources/FIRDiagnosticsData.h"

@interface FIRDiagnosticsDataTest : XCTestCase

@end

@implementation FIRDiagnosticsDataTest

/** Tests initialization. */
- (void)testInit {
  FIRDiagnosticsData *data = [[FIRDiagnosticsData alloc] init];
  XCTAssertNotNil(data);
}

/** Tests that -diagnosticObjects returns a valid default dictionary. */
- (void)testFIRCoreDiagnosticsData {
  FIRDiagnosticsData *data = [[FIRDiagnosticsData alloc] init];
  XCTAssertNotNil(data.diagnosticObjects);
  XCTAssertNotNil(data.diagnosticObjects[kFIRCDIsDataCollectionDefaultEnabledKey]);
  XCTAssertNotNil(data.diagnosticObjects[kFIRCDllAppsCountKey]);
  XCTAssertNotNil(data.diagnosticObjects[kFIRCDFirebaseUserAgentKey]);
}

/** Tests that setting diagnosticObjects throws. */
- (void)testSettingDiagnosticObjectsThrows {
  FIRDiagnosticsData *data = [[FIRDiagnosticsData alloc] init];
  XCTAssertThrows(data.diagnosticObjects = @{});
}

@end
