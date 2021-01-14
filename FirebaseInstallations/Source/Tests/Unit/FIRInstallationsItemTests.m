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

#import "FirebaseInstallations/Source/Library/FIRInstallationsItem.h"
#import "FirebaseInstallations/Source/Library/InstallationsStore/FIRInstallationsStoredItem.h"

#import "FirebaseInstallations/Source/Tests/Utils/FIRInstallationsItem+Tests.h"

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

- (void)testValidate_InvalidItem {
  FIRInstallationsItem *unregisteredItem = [[FIRInstallationsItem alloc] initWithAppID:@""
                                                                       firebaseAppName:@""];

  NSError *validationError;
  XCTAssertFalse([unregisteredItem isValid:&validationError]);
  XCTAssertTrue(
      [validationError.localizedFailureReason containsString:@"`appID` must not be empty"]);
  XCTAssertTrue([validationError.localizedFailureReason
      containsString:@"`firebaseAppName` must not be empty"]);
  XCTAssertTrue([validationError.localizedFailureReason
      containsString:@"`firebaseInstallationID` must not be empty"]);
  XCTAssertTrue(
      [validationError.localizedFailureReason containsString:@"invalid `registrationStatus`"]);

  FIRInstallationsItem *registerredItem = [[FIRInstallationsItem alloc] initWithAppID:@""
                                                                      firebaseAppName:@""];
  registerredItem.registrationStatus = FIRInstallationStatusRegistered;

  XCTAssertFalse([registerredItem isValid:&validationError]);
  XCTAssertTrue(
      [validationError.localizedFailureReason containsString:@"`appID` must not be empty"]);
  XCTAssertTrue([validationError.localizedFailureReason
      containsString:@"`firebaseAppName` must not be empty"]);
  XCTAssertTrue([validationError.localizedFailureReason
      containsString:@"`firebaseInstallationID` must not be empty"]);
  XCTAssertTrue([validationError.localizedFailureReason
      containsString:@"registered installation must have non-empty `refreshToken`"]);
  XCTAssertTrue([validationError.localizedFailureReason
      containsString:@"registered installation must have non-empty `authToken.token`"]);
  XCTAssertTrue([validationError.localizedFailureReason
      containsString:@"registered installation must have non-empty `authToken.expirationDate`"]);
}

- (void)testValidate_ValidItem {
  FIRInstallationsItem *item = [FIRInstallationsItem createRegisteredInstallationItem];

  NSError *error;
  XCTAssertTrue([item isValid:&error]);
  XCTAssertNil(error);
}

- (void)assertValidFID:(NSString *)FID {
  XCTAssertEqual(FID.length, 22);
  XCTAssertFalse([FID containsString:@"/"]);
  XCTAssertFalse([FID containsString:@"+"]);
}

@end
