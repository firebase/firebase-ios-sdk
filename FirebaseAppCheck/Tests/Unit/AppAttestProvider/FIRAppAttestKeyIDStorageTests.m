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

static NSString *const kAppName = @"testInitWithApp";
static NSString *const kAppID = @"app_id";

@interface FIRAppAttestKeyIDStorageTests : XCTestCase

@property(nonatomic) FIRAppAttestKeyIDStorage *storage;

@end

@implementation FIRAppAttestKeyIDStorageTests

- (void)setUp {
  [super setUp];

  self.storage = [[FIRAppAttestKeyIDStorage alloc] initWithAppName:kAppName appID:kAppID];
}

- (void)tearDown {
  // Remove the app attest key ID from storage.
  [self.storage setAppAttestKeyID:nil];
  self.storage = nil;

  [super tearDown];
}

- (void)testInitWithApp {
  XCTAssertNotNil([[FIRAppAttestKeyIDStorage alloc] initWithAppName:kAppName appID:kAppID]);
}

- (void)testSetAndGetAppAttestKeyID {
  NSString *appAttestKeyID = @"app_attest_key_ID";

  __auto_type setPromise = [self.storage setAppAttestKeyID:appAttestKeyID];
  XCTAssertEqualObjects(setPromise.value, appAttestKeyID);
  XCTAssertNil(setPromise.error);

  __auto_type getPromise = [self.storage getAppAttestKeyID];
  XCTAssertEqualObjects(getPromise.value, appAttestKeyID);
  XCTAssertNil(getPromise.error);
}

- (void)testRemoveAppAttestKeyID {
  __auto_type setPromise = [self.storage setAppAttestKeyID:nil];
  XCTAssertEqualObjects(setPromise.value, nil);
  XCTAssertNil(setPromise.error);
}

- (void)testGetAppAttestKeyID_WhenAppAttestKeyIDNotFoundError {
  __auto_type getPromise = [self.storage getAppAttestKeyID];
  XCTAssertNotNil(getPromise.error);
  XCTAssertEqualObjects(getPromise.error, [FIRAppCheckErrorUtil appAttestKeyIDNotFound]);
}

@end
