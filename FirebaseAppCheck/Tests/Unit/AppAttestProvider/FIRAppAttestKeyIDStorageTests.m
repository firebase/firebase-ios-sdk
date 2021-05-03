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

- (void)testSetAppAttestKeyIDPerApp {
  // 1. Create two additional key ID storages.
  //    This one shares the same app name as `self.storage`.
  FIRAppAttestKeyIDStorage *storage2 =
      [[FIRAppAttestKeyIDStorage alloc] initWithAppName:self.appName appID:@"app_id_2"];
  //    This one shares the same app id as `self.storage`.
  FIRAppAttestKeyIDStorage *storage3 =
      [[FIRAppAttestKeyIDStorage alloc] initWithAppName:@"FIRAppAttestKeyIDStorageTestsApp2"
                                                  appID:self.appID];

  // 2. Store an app attest key ID in an app's app attest key ID storage.
  NSString *appAttestKeyID = @"app_attest_key_ID";
  FBLPromise *setPromise = [self.storage setAppAttestKeyID:appAttestKeyID];
  XCTAssert(FBLWaitForPromisesWithTimeout(0.5));
  XCTAssertEqualObjects(setPromise.value, appAttestKeyID);
  XCTAssertNil(setPromise.error);

  // 3. Try to read the app attest key ID from the other app storages.
  __auto_type getPromise2 = [storage2 getAppAttestKeyID];
  XCTAssert(FBLWaitForPromisesWithTimeout(0.5));
  XCTAssertNotNil(getPromise2.error);
  XCTAssertEqualObjects(getPromise2.error, [FIRAppCheckErrorUtil appAttestKeyIDNotFound]);

  __auto_type getPromise3 = [storage3 getAppAttestKeyID];
  XCTAssert(FBLWaitForPromisesWithTimeout(0.5));
  XCTAssertNotNil(getPromise3.error);
  XCTAssertEqualObjects(getPromise3.error, [FIRAppCheckErrorUtil appAttestKeyIDNotFound]);

  // 4. Assert that storages can be updated independently.
  NSString *appAttestKeyID_2 = @"app_attest_key_ID_2";
  __auto_type setPromise2 = [storage2 setAppAttestKeyID:appAttestKeyID_2];
  XCTAssert(FBLWaitForPromisesWithTimeout(0.5));
  XCTAssertEqualObjects(setPromise2.value, appAttestKeyID_2);
  XCTAssertNil(setPromise2.error);

  NSString *appAttestKeyID_3 = @"app_attest_key_ID_3";
  __auto_type setPromise3 = [storage3 setAppAttestKeyID:appAttestKeyID_3];
  XCTAssert(FBLWaitForPromisesWithTimeout(0.5));
  XCTAssertEqualObjects(setPromise3.value, appAttestKeyID_3);
  XCTAssertNil(setPromise3.error);

  __auto_type getPromiseForAppAttestKeyID = [self.storage getAppAttestKeyID];
  XCTAssert(FBLWaitForPromisesWithTimeout(0.5));
  XCTAssertNil(getPromiseForAppAttestKeyID.error);

  __auto_type getPromiseForAppAttestKeyID_2 = [storage2 getAppAttestKeyID];
  XCTAssert(FBLWaitForPromisesWithTimeout(0.5));
  XCTAssertNil(getPromiseForAppAttestKeyID_2.error);

  __auto_type getPromiseForAppAttestKeyID_3 = [storage3 getAppAttestKeyID];
  XCTAssert(FBLWaitForPromisesWithTimeout(0.5));
  XCTAssertNil(getPromiseForAppAttestKeyID_3.error);

  XCTAssertNotEqualObjects(getPromiseForAppAttestKeyID.value, getPromiseForAppAttestKeyID_2.value);
  XCTAssertNotEqualObjects(getPromiseForAppAttestKeyID_2.value,
                           getPromiseForAppAttestKeyID_3.value);

  // 5. Cleanup other storages.
  [storage2 setAppAttestKeyID:nil];
  [storage3 setAppAttestKeyID:nil];
}

- (void)testGetAppAttestKeyID_WhenAppAttestKeyIDNotFoundError {
  __auto_type getPromise = [self.storage getAppAttestKeyID];
  XCTAssert(FBLWaitForPromisesWithTimeout(0.5));
  XCTAssertNotNil(getPromise.error);
  XCTAssertEqualObjects(getPromise.error, [FIRAppCheckErrorUtil appAttestKeyIDNotFound]);
}

@end
