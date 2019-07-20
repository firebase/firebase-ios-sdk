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
#import "FIRInstallationsItem.h"
#import "FIRInstallationsStoredItem.h"

@interface FIRInstallationsItemTests : XCTestCase

@end

// TODO: Add more tests.
@implementation FIRInstallationsItemTests

- (void)testInstallationsItemInit {
  NSString *appID = @"appID";
  NSString *name = @"name";
  FIRInstallationsItem *item = [[FIRInstallationsItem alloc] initWithAppID:appID
                                                           firebaseAppName:name];

  XCTAssertEqualObjects(item.appID, appID);
  XCTAssertEqualObjects(item.firebaseAppName, name);
}

- (void)testItemUpdateWithStoredItem {
  // TODO: Implement.
}

- (void)testGenerateFID {
  NSString *FID1 = [FIRInstallationsItem generateFID];
  [self assertValidFID:FID1];

  NSString *FID2 = [FIRInstallationsItem generateFID];
  XCTAssertEqual(FID2.length, 22);
  [self assertValidFID:FID2];

  XCTAssertNotEqualObjects(FID1, FID2);
}

- (void)assertValidFID:(NSString *)FID {
  XCTAssertEqual(FID.length, 22);
  XCTAssertFalse([FID containsString:@"/"]);
  XCTAssertFalse([FID containsString:@"+"]);
}

@end
