// Copyright 2024 Google LLC
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

#import "FirebaseCore/Tests/Unit/FIRTestCase.h"
#import "FirebaseCore/Sources/FIROptionsInternal.h"

@interface FIROptionsEqualityTest : FIRTestCase
@end

@implementation FIROptionsEqualityTest

/**
 * Tests a specific behavior where modifying the internal `libraryVersionID` (via KVC or internal setter)
 * causes `FIROptions` instances to be unequal, even though the public `libraryVersionID` getter
 * ignores this internal change and returns the global static version.
 *
 * This test documents:
 * 1. The `libraryVersionID` getter returns a static value, ignoring the instance's internal dictionary.
 * 2. The `isEqual:` implementation compares the internal dictionaries, leading to inequality.
 */
- (void)testEqualityWithInternalLibraryVersionIDDifference {
  // Setup two identical options
  FIROptions *options1 = [[FIROptions alloc] initWithGoogleAppID:@"appID" GCMSenderID:@"senderID"];
  FIROptions *options2 = [[FIROptions alloc] initWithGoogleAppID:@"appID" GCMSenderID:@"senderID"];

  // Verify initial equality
  XCTAssertEqualObjects(options1, options2);

  // Verify getters match initially
  XCTAssertEqualObjects(options1.libraryVersionID, options2.libraryVersionID);

  // Modify libraryVersionID on options1 using KVC.
  // This updates the internal options dictionary with key kFIRLibraryVersionID and value "customVersion".
  [options1 setValue:@"customVersion" forKey:@"libraryVersionID"];

  // Verify that the getter STILL returns the static global version.
  // This asserts that the getter is NOT reading from the dictionary we just updated.
  XCTAssertEqualObjects(options1.libraryVersionID, options2.libraryVersionID);

  // Verify that the objects are now NOT equal.
  // This asserts that isEqual: IS checking the dictionary we just updated.
  XCTAssertNotEqualObjects(options1, options2);
}

@end
