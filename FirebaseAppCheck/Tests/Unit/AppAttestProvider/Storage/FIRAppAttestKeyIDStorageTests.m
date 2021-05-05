/*
 * Copyright 2021 Google LLC
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

#import "FBLPromise+Testing.h"

#import "FirebaseAppCheck/Sources/AppAttestProvider/Storage/FIRAppAttestKeyIDStorage.h"

#import "FirebaseAppCheck/Sources/Core/Errors/FIRAppCheckErrorUtil.h"

@interface FIRAppAttestKeyIDStorageTests : XCTestCase
@property(nonatomic) NSString *appName;
@property(nonatomic) NSString *appID;
@property(nonatomic) FIRAppAttestKeyIDStorage *storage;
@end

@implementation FIRAppAttestKeyIDStorageTests

- (void)setUp {
  [super setUp];

  self.appName = @"FIRAppAttestKeyIDStorageTestsApp";
  self.appID = @"app_id";
  self.storage = [[FIRAppAttestKeyIDStorage alloc] initWithAppName:self.appName appID:self.appID];
}

- (void)tearDown {
  // Remove the app attest key ID from storage.
  [self.storage setAppAttestKeyID:nil];
  FBLWaitForPromisesWithTimeout(1.0);
  self.storage = nil;

  [super tearDown];
}

- (void)testInitWithApp {
  XCTAssertNotNil([[FIRAppAttestKeyIDStorage alloc] initWithAppName:self.appName appID:self.appID]);
}

- (void)testSetAndGetAppAttestKeyID {
  NSString *appAttestKeyID = @"app_attest_key_ID";

  FBLPromise *setPromise = [self.storage setAppAttestKeyID:appAttestKeyID];
  XCTAssert(FBLWaitForPromisesWithTimeout(0.5));
  XCTAssertEqualObjects(setPromise.value, appAttestKeyID);
  XCTAssertNil(setPromise.error);

  __auto_type getPromise = [self.storage getAppAttestKeyID];
  XCTAssert(FBLWaitForPromisesWithTimeout(0.5));
  XCTAssertEqualObjects(getPromise.value, appAttestKeyID);
  XCTAssertNil(getPromise.error);
}

- (void)testRemoveAppAttestKeyID {
  FBLPromise *setPromise = [self.storage setAppAttestKeyID:nil];
  XCTAssert(FBLWaitForPromisesWithTimeout(0.5));
  XCTAssertEqualObjects(setPromise.value, nil);
  XCTAssertNil(setPromise.error);
}

- (void)testGetAppAttestKeyID_WhenAppAttestKeyIDNotFoundError {
  __auto_type getPromise = [self.storage getAppAttestKeyID];
  XCTAssert(FBLWaitForPromisesWithTimeout(0.5));
  XCTAssertNotNil(getPromise.error);
  XCTAssertEqualObjects(getPromise.error, [FIRAppCheckErrorUtil appAttestKeyIDNotFound]);
}

- (void)testSetGetAppAttestKeyIDPerApp {
  // Assert storages for apps with the same name can independently set/get app attest key ID.
  [self assertIndependentSetGetForStoragesWithAppName1:self.appName
                                                appID1:@"app_id"
                                              appName2:self.appName
                                                appID2:@"app_id_2"];
  // Assert storages for apps with the same app ID can independently set/get app attest key ID.
  [self assertIndependentSetGetForStoragesWithAppName1:@"app_1"
                                                appID1:self.appID
                                              appName2:@"app_2"
                                                appID2:self.appID];
  // Assert storages for apps with different info can independently set/get app attest key ID.
  [self assertIndependentSetGetForStoragesWithAppName1:@"app_1"
                                                appID1:@"app_id_1"
                                              appName2:@"app_2"
                                                appID2:@"app_id_2"];
}

#pragma mark - Helpers

- (void)assertIndependentSetGetForStoragesWithAppName1:(NSString *)appName1
                                                appID1:(NSString *)appID1
                                              appName2:(NSString *)appName2
                                                appID2:(NSString *)appID2 {
  // Create two storages.
  FIRAppAttestKeyIDStorage *storage1 = [[FIRAppAttestKeyIDStorage alloc] initWithAppName:appName1
                                                                                   appID:appID1];
  FIRAppAttestKeyIDStorage *storage2 = [[FIRAppAttestKeyIDStorage alloc] initWithAppName:appName2
                                                                                   appID:appID2];
  // 1. Independently set app attest key IDs for the two storages.
  NSString *appAttestKeyID1 = @"app_attest_key_ID1";
  FBLPromise *setPromise1 = [storage1 setAppAttestKeyID:appAttestKeyID1];
  XCTAssert(FBLWaitForPromisesWithTimeout(0.5));
  XCTAssertEqualObjects(setPromise1.value, appAttestKeyID1);
  XCTAssertNil(setPromise1.error);

  NSString *appAttestKeyID2 = @"app_attest_key_ID2";
  __auto_type setPromise2 = [storage2 setAppAttestKeyID:appAttestKeyID2];
  XCTAssert(FBLWaitForPromisesWithTimeout(0.5));
  XCTAssertEqualObjects(setPromise2.value, appAttestKeyID2);
  XCTAssertNil(setPromise2.error);

  // 2. Get app attest key IDs for the two storages.
  __auto_type getPromise1 = [storage1 getAppAttestKeyID];
  XCTAssert(FBLWaitForPromisesWithTimeout(0.5));
  XCTAssertEqualObjects(getPromise1.value, appAttestKeyID1);
  XCTAssertNil(getPromise1.error);

  __auto_type getPromise2 = [storage2 getAppAttestKeyID];
  XCTAssert(FBLWaitForPromisesWithTimeout(0.5));
  XCTAssertEqualObjects(getPromise2.value, appAttestKeyID2);
  XCTAssertNil(getPromise2.error);

  // 3. Assert that the app attest key IDs were set and retrieved independently of one another.
  XCTAssertNotEqualObjects(getPromise1.value, getPromise2.value);

  // Cleanup storages.
  [storage1 setAppAttestKeyID:nil];
  XCTAssert(FBLWaitForPromisesWithTimeout(0.5));
  [storage2 setAppAttestKeyID:nil];
  XCTAssert(FBLWaitForPromisesWithTimeout(0.5));
}

@end
