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

#import "FirebaseInstallations/Source/Tests/Utils/FIRKeyedArchivingUtils.h"

#import "FirebaseInstallations/Source/Library/InstallationsStore/FIRInstallationsStoredAuthToken.h"
#import "FirebaseInstallations/Source/Library/InstallationsStore/FIRInstallationsStoredItem.h"

@interface FIRInstallationsStoredItemTests : XCTestCase

@end

@implementation FIRInstallationsStoredItemTests

- (void)testItemArchivingUnarchiving {
  FIRInstallationsStoredAuthToken *authToken = [[FIRInstallationsStoredAuthToken alloc] init];
  authToken.token = @"auth-token";
  authToken.expirationDate = [NSDate dateWithTimeIntervalSinceNow:12345];
  authToken.status = FIRInstallationsAuthTokenStatusTokenReceived;

  FIRInstallationsStoredItem *item = [[FIRInstallationsStoredItem alloc] init];
  item.firebaseInstallationID = @"inst-id";
  item.refreshToken = @"refresh-token";
  item.authToken = authToken;
  item.registrationStatus = FIRInstallationStatusRegistered;
  item.IIDDefaultToken = @"IIDTokenValue";

  NSError *error;
  NSData *archivedItem = [FIRKeyedArchivingUtils archivedDataWithRootObject:item error:&error];
  XCTAssertNotNil(archivedItem, @"Error: %@", error);

  FIRInstallationsStoredItem *unarchivedItem =
      [FIRKeyedArchivingUtils unarchivedObjectOfClass:[FIRInstallationsStoredItem class]
                                             fromData:archivedItem
                                                error:&error];
  XCTAssertNotNil(unarchivedItem, @"Error: %@", error);

  XCTAssertEqualObjects(unarchivedItem.firebaseInstallationID, item.firebaseInstallationID);
  XCTAssertEqualObjects(unarchivedItem.refreshToken, item.refreshToken);
  XCTAssertEqualObjects(unarchivedItem.authToken.token, item.authToken.token);
  XCTAssertEqualObjects(unarchivedItem.authToken.expirationDate, item.authToken.expirationDate);
  XCTAssertEqual(unarchivedItem.registrationStatus, item.registrationStatus);
  XCTAssertEqualObjects(unarchivedItem.IIDDefaultToken, item.IIDDefaultToken);
}

@end
