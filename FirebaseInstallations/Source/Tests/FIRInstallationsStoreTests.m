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

#import <OCMock/OCMock.h>

#import <GoogleUtilities/GULUserDefaults.h>
#import "FBLPromise+Testing.h"
#import "FIRInstallationsErrorUtil.h"
#import "FIRInstallationsItem.h"
#import "FIRInstallationsStore.h"
#import "FIRInstallationsStoredItem.h"
#import "FIRSecureStorage.h"

@interface FIRInstallationsStoreTests : XCTestCase
@property(nonatomic) FIRInstallationsStore *store;
@property(nonatomic) id mockSecureStorage;
@property(nonatomic) GULUserDefaults *userDefaults;
@end

@implementation FIRInstallationsStoreTests

- (void)setUp {
  self.mockSecureStorage = OCMStrictClassMock([FIRSecureStorage class]);
  self.store = [[FIRInstallationsStore alloc] initWithSecureStorage:self.mockSecureStorage
                                                        accessGroup:nil];
  self.userDefaults =
      [[GULUserDefaults alloc] initWithSuiteName:kFIRInstallationsStoreUserDefaultsID];
}

- (void)tearDown {
  self.store = nil;
  self.mockSecureStorage = nil;
}

- (void)testInstallationID_WhenNoUserDefaultsItem_ThenNotFound {
  NSString *appID = @"123";
  NSString *appName = @"name";
  NSString *itemID = [self itemIDWithAppID:appID appName:appName];

  [self.userDefaults removeObjectForKey:itemID];

  // Check with empty keychain.
  OCMStub([self.mockSecureStorage getObjectForKey:itemID
                                      objectClass:[FIRInstallationsStoredItem class]
                                      accessGroup:nil])
      .andReturn([FBLPromise resolvedWith:nil]);

  [self assertInstallationIDNotFoundForAppID:appID appName:appName caller:@"Empty keychain"];

  // Check when there is a keychain item.
  OCMStub([self.mockSecureStorage getObjectForKey:itemID
                                      objectClass:[FIRInstallationsStoredItem class]
                                      accessGroup:nil])
      .andReturn([FBLPromise resolvedWith:[[FIRInstallationsStoredItem alloc] init]]);

  [self assertInstallationIDNotFoundForAppID:appID appName:appName caller:@"Non-empty keychain"];
}

- (void)testInstallationID_WhenThereIsUserDefaultsAndKeychain_ThenReturnsItem {
  NSString *appID = @"123";
  NSString *appName = @"name";
  NSString *itemID = [self itemIDWithAppID:appID appName:appName];

  [self.userDefaults setObject:@(YES) forKey:itemID];

  FIRInstallationsStoredItem *storedItem = [self createValidStoredItem];

  // Check when there is a keychain item.
  OCMStub([self.mockSecureStorage getObjectForKey:itemID
                                      objectClass:[FIRInstallationsStoredItem class]
                                      accessGroup:nil])
  .andReturn([FBLPromise resolvedWith:storedItem]);

  FBLPromise<FIRInstallationsItem *> *itemPromise = [self.store installationForAppID:appID
                                                                             appName:appName];
  XCTAssert(FBLWaitForPromisesWithTimeout(0.5));

  XCTAssertTrue(itemPromise.isFulfilled);
  XCTAssertNil(itemPromise.error);
  XCTAssertNotNil(itemPromise.value);
  FIRInstallationsItem *item = itemPromise.value;
  XCTAssertEqualObjects(item.appID, appID);
  XCTAssertEqualObjects(item.firebaseAppName, appName);
  XCTAssertEqualObjects(item.refreshToken, storedItem.refreshToken);
  XCTAssertEqualObjects(item.firebaseInstallationID, storedItem.firebaseInstallationID);
}

#pragma mark - Common

- (void)assertInstallationIDNotFoundForAppID:(NSString *)appID
                                     appName:(NSString *)appName
                                      caller:(NSString *)caller {
  FBLPromise<FIRInstallationsItem *> *itemPromise = [self.store installationForAppID:appID
                                                                             appName:appName];

  XCTAssert(FBLWaitForPromisesWithTimeout(0.5));

  XCTAssertTrue(itemPromise.isRejected, @"%@", caller);
  XCTAssertEqualObjects(itemPromise.error,
                        [FIRInstallationsErrorUtil installationItemNotFoundForAppID:appID
                                                                            appName:appName],
                        @"%@", caller);
}

#pragma mark - Helpers

- (NSString *)itemIDWithAppID:(NSString *)appID appName:(NSString *)appName {
  return [[[FIRInstallationsItem alloc] initWithAppID:appID firebaseAppName:appName] identifier];
}

- (FIRInstallationsStoredItem *)createValidStoredItem {
  FIRInstallationsStoredItem *storedItem = [[FIRInstallationsStoredItem alloc] init];

  storedItem.firebaseInstallationID = @"firebaseInstallationID";
  storedItem.refreshToken = @"refreshToken";

  return storedItem;
}

@end
