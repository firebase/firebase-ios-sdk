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
  self.storage = nil;

  [super tearDown];
}

- (void)testInitWithApp {
  XCTAssertNotNil([[FIRAppAttestKeyIDStorage alloc] initWithAppName:self.appName appID:self.appID]);
}

- (void)testSetAndGetAppAttestKeyID {
  NSString *appAttestKeyID = @"app_attest_key_ID";

  FBLPromise *setPromise = [self.storage setAppAttestKeyID:appAttestKeyID];
  XCTAssertEqualObjects(setPromise.value, appAttestKeyID);
  XCTAssertNil(setPromise.error);

  __auto_type getPromise = [self.storage getAppAttestKeyID];
  XCTAssertEqualObjects(getPromise.value, appAttestKeyID);
  XCTAssertNil(getPromise.error);
}

- (void)testRemoveAppAttestKeyID {
  FBLPromise *setPromise = [self.storage setAppAttestKeyID:nil];
  XCTAssertEqualObjects(setPromise.value, nil);
  XCTAssertNil(setPromise.error);
}

- (void)testSetAppAttestKeyIDPerApp {
  // 1. Store an app attest key ID in an app's app attest key ID storage.
  NSString *appAttestKeyID = @"app_attest_key_ID";

  FBLPromise *setPromise = [self.storage setAppAttestKeyID:appAttestKeyID];
  XCTAssertEqualObjects(setPromise.value, appAttestKeyID);
  XCTAssertNil(setPromise.error);

  // 2. Try to read the app attest key ID in another app's app attest key ID storage.
  FIRAppAttestKeyIDStorage *storage2 =
      [[FIRAppAttestKeyIDStorage alloc] initWithAppName:self.appName appID:@"app_id_2"];
  __auto_type getPromise = [storage2 getAppAttestKeyID];
  XCTAssertNotNil(getPromise.error);
  XCTAssertEqualObjects(getPromise.error, [FIRAppCheckErrorUtil appAttestKeyIDNotFound]);
}

- (void)testGetAppAttestKeyID_WhenAppAttestKeyIDNotFoundError {
  __auto_type getPromise = [self.storage getAppAttestKeyID];
  XCTAssertNotNil(getPromise.error);
  XCTAssertEqualObjects(getPromise.error, [FIRAppCheckErrorUtil appAttestKeyIDNotFound]);
}

@end
