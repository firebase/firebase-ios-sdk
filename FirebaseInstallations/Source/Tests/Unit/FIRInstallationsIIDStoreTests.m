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

#import <FirebaseInstanceID/FirebaseInstanceID.h>
#import "FBLPromise+Testing.h"
#import "FirebaseInstallations/Source/Tests/Utils/FIRTestKeychain.h"

#import "FirebaseInstallations/Source/Library/IIDMigration/FIRInstallationsIIDStore.h"

@interface FIRInstanceID (Tests)
+ (FIRInstanceID *)instanceIDForTests;
@end

@interface FIRInstallationsIIDStoreTests : XCTestCase
@property(nonatomic) FIRInstanceID *instanceID;
@property(nonatomic) FIRInstallationsIIDStore *IIDStore;
#if TARGET_OS_OSX
@property(nonatomic) FIRTestKeychain *privateKeychain;
#endif  // TARGET_OSX
@end

@implementation FIRInstallationsIIDStoreTests

- (void)setUp {
  self.instanceID = [FIRInstanceID instanceIDForTests];
  self.IIDStore = [[FIRInstallationsIIDStore alloc] init];

#if TARGET_OS_OSX
  self.privateKeychain = [[FIRTestKeychain alloc] init];
  self.IIDStore.keychainRef = self.privateKeychain.testKeychainRef;
#endif  // TARGET_OSX
}

- (void)tearDown {
  self.instanceID = nil;
#if TARGET_OS_OSX
  self.privateKeychain = nil;
#endif  // TARGET_OSX
}

// TODO: Configure the tests to run on macOS without requesting the keychain password.
#if !TARGET_OS_OSX
- (void)testExistingIIDSuccess {
  NSString *existingIID = [self readExistingIID];

  FBLPromise<NSString *> *IIDPromise = [self.IIDStore existingIID];

  XCTAssert(FBLWaitForPromisesWithTimeout(0.5));

  XCTAssertNil(IIDPromise.error);
  XCTAssertEqualObjects(IIDPromise.value, existingIID);
  NSLog(@"Existing IID: %@", IIDPromise.value);
}

- (void)testDeleteExistingIID {
  // 1. Generate IID.
  NSString *existingIID1 = [self readExistingIID];

  // 2. Delete IID.
  FBLPromise<NSNull *> *deletePromise = [self.IIDStore deleteExistingIID];
  XCTAssert(FBLWaitForPromisesWithTimeout(0.5));

  XCTAssertNil(deletePromise.error);
  XCTAssertTrue(deletePromise.isFulfilled);

  // 3. Check there is no IID.
  FBLPromise<NSString *> *IIDPromise = [self.IIDStore existingIID];
  XCTAssert(FBLWaitForPromisesWithTimeout(0.5));

  XCTAssertNotNil(IIDPromise.error);
  XCTAssertTrue(IIDPromise.isRejected);

  // 4. Re-instantiate IID instance to reset its in-memory cache.
  self.instanceID = [FIRInstanceID instanceIDForTests];

  // 5. Generate a new IID and check it is different.
  NSString *existingIID2 = [self readExistingIID];
  XCTAssertNotEqualObjects(existingIID1, existingIID2);
}

#endif  // !TARGET_OSX

#pragma mark - Helpers

- (NSString *)readExistingIID {
  __block NSString *existingIID;

  XCTestExpectation *IIDExpectation = [self expectationWithDescription:@"IIDExpectation"];
  [self.instanceID getIDWithHandler:^(NSString *_Nullable identity, NSError *_Nullable error) {
    XCTAssertNil(error);
    XCTAssertNotNil(identity);
    existingIID = identity;
    [IIDExpectation fulfill];
  }];

  [self waitForExpectations:@[ IIDExpectation ] timeout:20];

  return existingIID;
}

@end
