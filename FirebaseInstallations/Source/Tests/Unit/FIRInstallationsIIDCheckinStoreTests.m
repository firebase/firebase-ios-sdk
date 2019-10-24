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

#import "FBLPromise+Testing.h"

#import "FIRInstanceIDBackupExcludedPlist.h"
#import "FIRInstanceIDCheckinPreferences+Internal.h"
#import "FIRInstanceIDCheckinStore.h"
#import "FIRInstanceIDStore.h"

#import "FIRInstallationsIIDCheckinStore.h"
#import "FIRInstallationsStoredIIDCheckin.h"

static NSString *const kFakeCheckinPlistName = @"com.google.test.IIDStoreTestCheckin";
static NSString *const kSubDirectoryName = @"FIRInstallationsIIDCheckinStoreTests";

@interface FIRInstallationsIIDCheckinStoreTests : XCTestCase
@property(nonatomic) FIRInstallationsIIDCheckinStore *installationsIIDCheckinStore;

@property(nonatomic) FIRInstanceIDCheckinStore *IIDCheckinStore;
//@property(nonatomic) FIRInstanceIDBackupExcludedPlist *IIDPlist;
//@property(nonatomic) FIRInstanceIDAuthKeychain *IIDKeychain;
@end

@implementation FIRInstallationsIIDCheckinStoreTests

- (void)setUp {
  self.installationsIIDCheckinStore = [[FIRInstallationsIIDCheckinStore alloc] init];

  [FIRInstanceIDStore createSubDirectory:kSubDirectoryName];
  self.IIDCheckinStore =
      [[FIRInstanceIDCheckinStore alloc] initWithCheckinPlistFileName:kFakeCheckinPlistName
                                                     subDirectoryName:kSubDirectoryName];
}

- (void)tearDown {
  self.installationsIIDCheckinStore = nil;
}

- (void)testExistingCheckin_WhenNoCheckin_ThenFails {
  [self removeIIDCheckingPreferences];

  FBLPromise *checkinPromise = [self.installationsIIDCheckinStore existingCheckin];
  XCTAssert(FBLWaitForPromisesWithTimeout(1));

  XCTAssertTrue(checkinPromise.isRejected);
  XCTAssertNil(checkinPromise.value);
  XCTAssertNotNil(checkinPromise.error);
}

- (void)testExistingCheckinSuccess {
  FIRInstanceIDCheckinPreferences *savedCheckin = [self saveIIDCheckingPreferences];

  __auto_type checkinPromise = [self.installationsIIDCheckinStore existingCheckin];
  XCTAssert(FBLWaitForPromisesWithTimeout(1));

  XCTAssertTrue(checkinPromise.isFulfilled);
  XCTAssertNil(checkinPromise.error);
  XCTAssertNotNil(checkinPromise.value);

  XCTAssertEqualObjects(checkinPromise.value.deviceID, savedCheckin.deviceID);
  XCTAssertEqualObjects(checkinPromise.value.secretToken, savedCheckin.secretToken);
}

#pragma mark - Helpers

- (FIRInstanceIDCheckinPreferences *)saveIIDCheckingPreferences {
  FIRInstanceIDCheckinPreferences *checkin =
      [[FIRInstanceIDCheckinPreferences alloc] initWithDeviceID:@"deviceID"
                                                    secretToken:@"secretToken"];
  XCTestExpectation *expectation = [self expectationWithDescription:@"saveIIDCheckingPreferences"];
  [self.IIDCheckinStore saveCheckinPreferences:checkin
                                       handler:^(NSError *error) {
                                         XCTAssertNil(error);
                                         [expectation fulfill];
                                       }];

  [self waitForExpectations:@[ expectation ] timeout:1];
  return checkin;
}

- (void)removeIIDCheckingPreferences {
  XCTestExpectation *expectation =
      [self expectationWithDescription:@"removeIIDCheckingPreferences"];
  [self.IIDCheckinStore removeCheckinPreferencesWithHandler:^(NSError *error) {
    XCTAssertNil(error);
    [expectation fulfill];
  }];
  [self waitForExpectations:@[ expectation ] timeout:1];
}

@end
