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

#import <GoogleUtilities/GULKeychainStorage.h>
#import <GoogleUtilities/GULUserDefaults.h>

#import "FBLPromise+Testing.h"
#import "FirebaseInstallations/Source/Library/Errors/FIRInstallationsErrorUtil.h"
#import "FirebaseInstallations/Source/Library/FIRInstallationsItem.h"
#import "FirebaseInstallations/Source/Library/InstallationsStore/FIRInstallationsStore.h"
#import "FirebaseInstallations/Source/Library/InstallationsStore/FIRInstallationsStoredItem.h"
#import "FirebaseInstallations/Source/Tests/Utils/FIRInstallationsItem+Tests.h"

@interface FIRInstallationsStoreTests : XCTestCase
@property(nonatomic) NSString *accessGroup;
@property(nonatomic) FIRInstallationsStore *store;
@property(nonatomic) id mockSecureStorage;
@property(nonatomic) GULUserDefaults *userDefaults;
@end

@implementation FIRInstallationsStoreTests

- (void)setUp {
  self.accessGroup = @"accessGroup";
  self.mockSecureStorage = OCMClassMock([GULKeychainStorage class]);
  self.store = [[FIRInstallationsStore alloc] initWithSecureStorage:self.mockSecureStorage
                                                        accessGroup:self.accessGroup];

  // TODO: Replace real user defaults by an injected mock or a test specific user defaults instance
  // with a specific suite name.
  self.userDefaults = [[GULUserDefaults alloc] initWithSuiteName:self.accessGroup];
}

- (void)tearDown {
  self.userDefaults = nil;
  self.store = nil;
  self.mockSecureStorage = nil;
  [self.mockSecureStorage stopMocking];
}

- (void)testInstallationID_WhenNoUserDefaultsItem_ThenNotFound {
  NSString *appID = @"123";
  NSString *appName = @"name";
  NSString *itemID = [self itemIDWithAppID:appID appName:appName];

  [self.userDefaults removeObjectForKey:itemID];

  // Check with empty keychain.
  OCMReject([self.mockSecureStorage getObjectForKey:[OCMArg any]
                                        objectClass:[OCMArg any]
                                        accessGroup:[OCMArg any]]);

  [self assertInstallationIDNotFoundForAppID:appID appName:appName];
  OCMVerifyAll(self.mockSecureStorage);
}

- (void)testInstallationID_WhenThereIsUserDefaultsAndKeychain_ThenReturnsItem {
  NSString *appID = @"123";
  NSString *appName = @"name";
  NSString *itemID = [self itemIDWithAppID:appID appName:appName];

  [self.userDefaults setObject:@(YES) forKey:itemID];

  FIRInstallationsStoredItem *storedItem = [self createValidStoredItem];

  OCMExpect([self.mockSecureStorage getObjectForKey:itemID
                                        objectClass:[FIRInstallationsStoredItem class]
                                        accessGroup:self.accessGroup])
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
  [self assertStoredItem:storedItem correspondsToItem:item];

  OCMVerifyAll(self.mockSecureStorage);
}

- (void)testInstallationID_WhenThereIsUserDefaultsAndNoKeychain_ThenNotFound {
  NSString *appID = @"123";
  NSString *appName = @"name";
  NSString *itemID = [self itemIDWithAppID:appID appName:appName];

  [self.userDefaults setObject:@(YES) forKey:itemID];

  OCMExpect([self.mockSecureStorage getObjectForKey:itemID
                                        objectClass:[FIRInstallationsStoredItem class]
                                        accessGroup:self.accessGroup])
      .andReturn([FBLPromise resolvedWith:nil]);

  FBLPromise<FIRInstallationsItem *> *itemPromise = [self.store installationForAppID:appID
                                                                             appName:appName];
  XCTAssert(FBLWaitForPromisesWithTimeout(0.5));

  XCTAssertNotNil(itemPromise.error);
  XCTAssertEqualObjects(itemPromise.error,
                        [FIRInstallationsErrorUtil installationItemNotFoundForAppID:appID
                                                                            appName:appName]);
  XCTAssertNil(itemPromise.value);

  OCMVerifyAll(self.mockSecureStorage);
}

- (void)testSaveInstallationWhenKeychainSucceds {
  FIRInstallationsItem *item = [FIRInstallationsItem createUnregisteredInstallationItem];
  NSString *itemID = [item identifier];
  // Reset user defaults key.
  [self.userDefaults removeObjectForKey:itemID];

  id storedItemArg = [OCMArg checkWithBlock:^BOOL(FIRInstallationsStoredItem *obj) {
    XCTAssertEqualObjects([obj class], [FIRInstallationsStoredItem class]);
    [self assertStoredItem:obj correspondsToItem:item];
    return YES;
  }];
  OCMExpect([self.mockSecureStorage setObject:storedItemArg
                                       forKey:itemID
                                  accessGroup:self.accessGroup])
      .andReturn([FBLPromise resolvedWith:[NSNull null]]);

  FBLPromise<NSNull *> *promise = [self.store saveInstallation:item];
  XCTAssert(FBLWaitForPromisesWithTimeout(0.5));

  XCTAssertNil(promise.error);
  XCTAssertTrue(promise.isFulfilled);

  OCMVerifyAll(self.mockSecureStorage);

  // Check the user defaults key updated.
  XCTAssertNotNil([self.userDefaults objectForKey:itemID]);
}

- (void)testSaveInstallationWhenKeychainFails {
  FIRInstallationsItem *item = [FIRInstallationsItem createUnregisteredInstallationItem];
  NSString *itemID = [item identifier];
  // Reset user defaults key.
  [self.userDefaults removeObjectForKey:itemID];

  NSError *keychainError = [FIRInstallationsErrorUtil keychainErrorWithFunction:@"Get" status:-1];
  FBLPromise *rejectedPromise = [FBLPromise pendingPromise];
  [rejectedPromise reject:keychainError];

  id storedItemArg = [OCMArg checkWithBlock:^BOOL(FIRInstallationsStoredItem *obj) {
    XCTAssertEqualObjects([obj class], [FIRInstallationsStoredItem class]);
    [self assertStoredItem:obj correspondsToItem:item];
    return YES;
  }];
  OCMExpect([self.mockSecureStorage setObject:storedItemArg
                                       forKey:itemID
                                  accessGroup:self.accessGroup])
      .andReturn(rejectedPromise);

  FBLPromise<NSNull *> *promise = [self.store saveInstallation:item];
  XCTAssert(FBLWaitForPromisesWithTimeout(0.5));

  XCTAssertTrue(promise.isRejected);
  XCTAssertEqualObjects(promise.error, keychainError);

  OCMVerifyAll(self.mockSecureStorage);

  // Check the user defaults key wasn't updated.
  XCTAssertNil([self.userDefaults objectForKey:itemID]);
}

- (void)testRemoveInstallation {
  NSString *appID = @"123";
  NSString *appName = @"name";
  NSString *itemID = [self itemIDWithAppID:appID appName:appName];

  [self.userDefaults setObject:@(YES) forKey:itemID];

  OCMExpect([self.mockSecureStorage removeObjectForKey:itemID accessGroup:self.accessGroup])
      .andReturn([FBLPromise resolvedWith:[NSNull null]]);

  FBLPromise<NSNull *> *promise = [self.store removeInstallationForAppID:appID appName:appName];
  XCTAssert(FBLWaitForPromisesWithTimeout(0.5));

  XCTAssertTrue(promise.isFulfilled);
  XCTAssertNil(promise.error);

  OCMVerifyAll(self.mockSecureStorage);

  XCTAssertNil([self.userDefaults objectForKey:itemID]);
}

#pragma mark - Common

- (void)assertInstallationIDNotFoundForAppID:(NSString *)appID appName:(NSString *)appName {
  FBLPromise<FIRInstallationsItem *> *itemPromise = [self.store installationForAppID:appID
                                                                             appName:appName];

  XCTAssert(FBLWaitForPromisesWithTimeout(0.5));

  XCTAssertTrue(itemPromise.isRejected, @"%@", self.name);
  XCTAssertEqualObjects(itemPromise.error,
                        [FIRInstallationsErrorUtil installationItemNotFoundForAppID:appID
                                                                            appName:appName],
                        @"%@", self.name);
}

#pragma mark - Helpers

- (NSString *)itemIDWithAppID:(NSString *)appID appName:(NSString *)appName {
  return [FIRInstallationsItem identifierWithAppID:appID appName:appName];
}

- (FIRInstallationsStoredItem *)createValidStoredItem {
  FIRInstallationsStoredItem *storedItem = [[FIRInstallationsStoredItem alloc] init];

  storedItem.firebaseInstallationID = @"firebaseInstallationID";
  storedItem.refreshToken = @"refreshToken";

  return storedItem;
}

- (void)assertStoredItem:(FIRInstallationsStoredItem *)storedItem
       correspondsToItem:(FIRInstallationsItem *)item {
  XCTAssertEqualObjects(item.refreshToken, storedItem.refreshToken);
  XCTAssertEqualObjects(item.firebaseInstallationID, storedItem.firebaseInstallationID);
  XCTAssertEqual(item.registrationStatus, storedItem.registrationStatus);
}

@end
