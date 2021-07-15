/*
 * Copyright 2020 Google LLC
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

#import "FBLPromise+Testing.h"

#import "FirebaseAppCheck/Sources/Core/Storage/FIRAppCheckStorage.h"

#import "FirebaseAppCheck/Sources/Core/Errors/FIRAppCheckErrorUtil.h"
#import "FirebaseAppCheck/Sources/Core/FIRAppCheckToken+Internal.h"

@interface FIRAppCheckStorageTests : XCTestCase
@property(nonatomic) NSString *appName;
@property(nonatomic) NSString *appID;
@property(nonatomic) FIRAppCheckStorage *storage;
@end

@implementation FIRAppCheckStorageTests

- (void)setUp {
  [super setUp];

  self.appName = @"FIRAppCheckStorageTestsApp";
  self.appID = @"1:100000000000:ios:aaaaaaaaaaaaaaaaaaaaaaaa";
  self.storage = [[FIRAppCheckStorage alloc] initWithAppName:self.appName
                                                       appID:self.appID
                                                 accessGroup:nil];
}

- (void)tearDown {
  self.storage = nil;
  [super tearDown];
}

#if !TARGET_OS_MACCATALYST  // Catalyst should be possible with Xcode 12.5+

- (void)testSetAndGetToken {
  FIRAppCheckToken *tokenToStore = [[FIRAppCheckToken alloc] initWithToken:@"token"
                                                            expirationDate:[NSDate distantPast]
                                                            receivedAtDate:[NSDate date]];

  FBLPromise *setPromise = [self.storage setToken:tokenToStore];
  XCTAssert(FBLWaitForPromisesWithTimeout(0.5));
  XCTAssertEqualObjects(setPromise.value, tokenToStore);
  XCTAssertNil(setPromise.error);

  __auto_type getPromise = [self.storage getToken];
  XCTAssert(FBLWaitForPromisesWithTimeout(0.5));
  XCTAssertEqualObjects(getPromise.value.token, tokenToStore.token);
  XCTAssertEqualObjects(getPromise.value.expirationDate, tokenToStore.expirationDate);
  XCTAssertEqualObjects(getPromise.value.receivedAtDate, tokenToStore.receivedAtDate);
  XCTAssertNil(getPromise.error);
}

- (void)testRemoveToken {
  FBLPromise *setPromise = [self.storage setToken:nil];
  XCTAssert(FBLWaitForPromisesWithTimeout(0.5));
  XCTAssertEqualObjects(setPromise.value, nil);
  XCTAssertNil(setPromise.error);

  __auto_type getPromise = [self.storage getToken];
  XCTAssert(FBLWaitForPromisesWithTimeout(0.5));
  XCTAssertNil(getPromise.value);
  XCTAssertNil(getPromise.error);
}

- (void)testGetToken_KeychainError {
  // 1. Set up storage mock.
  id mockKeychainStorage = OCMClassMock([GULKeychainStorage class]);
  FIRAppCheckStorage *storage = [[FIRAppCheckStorage alloc] initWithAppName:self.appName
                                                                      appID:self.appID
                                                            keychainStorage:mockKeychainStorage
                                                                accessGroup:nil];
  // 2. Create and expect keychain error.
  NSError *gulsKeychainError = [NSError errorWithDomain:@"com.guls.keychain" code:-1 userInfo:nil];
  OCMExpect([mockKeychainStorage getObjectForKey:[OCMArg any]
                                     objectClass:[OCMArg any]
                                     accessGroup:[OCMArg any]])
      .andReturn([FBLPromise resolvedWith:gulsKeychainError]);

  // 3. Get token and verify results.
  __auto_type getPromise = [storage getToken];
  XCTAssert(FBLWaitForPromisesWithTimeout(0.5));
  XCTAssertNotNil(getPromise.error);
  XCTAssertEqualObjects(getPromise.error,
                        [FIRAppCheckErrorUtil keychainErrorWithError:gulsKeychainError]);

  // 4. Verify storage mock.
  OCMVerifyAll(mockKeychainStorage);
}

- (void)testSetToken_KeychainError {
  // 1. Set up storage mock.
  id mockKeychainStorage = OCMClassMock([GULKeychainStorage class]);
  FIRAppCheckStorage *storage = [[FIRAppCheckStorage alloc] initWithAppName:self.appName
                                                                      appID:self.appID
                                                            keychainStorage:mockKeychainStorage
                                                                accessGroup:nil];

  // 2. Create and expect keychain error.
  NSError *gulsKeychainError = [NSError errorWithDomain:@"com.guls.keychain" code:-1 userInfo:nil];
  OCMExpect([mockKeychainStorage setObject:[OCMArg any]
                                    forKey:[OCMArg any]
                               accessGroup:[OCMArg any]])
      .andReturn([FBLPromise resolvedWith:gulsKeychainError]);

  // 3. Set token and verify results.
  FIRAppCheckToken *tokenToStore = [[FIRAppCheckToken alloc] initWithToken:@"token"
                                                            expirationDate:[NSDate distantPast]
                                                            receivedAtDate:[NSDate date]];
  __auto_type getPromise = [storage setToken:tokenToStore];
  XCTAssert(FBLWaitForPromisesWithTimeout(0.5));
  XCTAssertNotNil(getPromise.error);
  XCTAssertEqualObjects(getPromise.error,
                        [FIRAppCheckErrorUtil keychainErrorWithError:gulsKeychainError]);

  // 4. Verify storage mock.
  OCMVerifyAll(mockKeychainStorage);
}

- (void)testRemoveToken_KeychainError {
  // 1. Set up storage mock.
  id mockKeychainStorage = OCMClassMock([GULKeychainStorage class]);
  FIRAppCheckStorage *storage = [[FIRAppCheckStorage alloc] initWithAppName:self.appName
                                                                      appID:self.appID
                                                            keychainStorage:mockKeychainStorage
                                                                accessGroup:nil];

  // 2. Create and expect keychain error.
  NSError *gulsKeychainError = [NSError errorWithDomain:@"com.guls.keychain" code:-1 userInfo:nil];
  OCMExpect([mockKeychainStorage removeObjectForKey:[OCMArg any] accessGroup:[OCMArg any]])
      .andReturn([FBLPromise resolvedWith:gulsKeychainError]);

  // 3. Remove token and verify results.
  __auto_type getPromise = [storage setToken:nil];
  XCTAssert(FBLWaitForPromisesWithTimeout(0.5));
  XCTAssertNotNil(getPromise.error);
  XCTAssertEqualObjects(getPromise.error,
                        [FIRAppCheckErrorUtil keychainErrorWithError:gulsKeychainError]);

  // 4. Verify storage mock.
  OCMVerifyAll(mockKeychainStorage);
}

- (void)testSetTokenPerApp {
  // 1. Set token with a storage.
  FIRAppCheckToken *tokenToStore = [[FIRAppCheckToken alloc] initWithToken:@"token"
                                                            expirationDate:[NSDate distantPast]
                                                            receivedAtDate:[NSDate date]];

  FBLPromise *setPromise = [self.storage setToken:tokenToStore];
  XCTAssert(FBLWaitForPromisesWithTimeout(0.5));
  XCTAssertEqualObjects(setPromise.value, tokenToStore);
  XCTAssertNil(setPromise.error);

  // 2. Try to read the token with another storage.
  FIRAppCheckStorage *storage2 =
      [[FIRAppCheckStorage alloc] initWithAppName:self.appName
                                            appID:@"1:200000000000:ios:aaaaaaaaaaaaaaaaaaaaaaaa"
                                      accessGroup:nil];
  __auto_type getPromise = [storage2 getToken];
  XCTAssert(FBLWaitForPromisesWithTimeout(0.5));
  XCTAssertNil(getPromise.value);
  XCTAssertNil(getPromise.error);
}
#endif  // !TARGET_OS_MACCATALYST

@end
