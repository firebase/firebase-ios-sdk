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

#import <TargetConditionals.h>

// Tests that use the Keychain require a host app and Swift Package Manager
// does not support adding a host app to test targets.
#if !SWIFT_PACKAGE

// Skip keychain tests on Catalyst and macOS. Tests are skipped because they
// involve interactions with the keychain that require a provisioning profile.
// See go/firebase-macos-keychain-popups for more details.
#if !TARGET_OS_MACCATALYST && !TARGET_OS_OSX

#import <XCTest/XCTest.h>

#import <OCMock/OCMock.h>

#import <GoogleUtilities/GULKeychainStorage.h>

#import "FBLPromise+Testing.h"

#import "AppCheck/Sources/Core/Storage/GACAppCheckStorage.h"

#import "AppCheck/Sources/Core/Errors/GACAppCheckErrorUtil.h"
#import "AppCheck/Sources/Core/GACAppCheckToken+Internal.h"

static NSString *const kAppName = @"GACAppCheckStorageTestsApp";
static NSString *const kGoogleAppID = @"1:100000000000:ios:aaaaaaaaaaaaaaaaaaaaaaaa";

@interface GACAppCheckStorageTests : XCTestCase
@property(nonatomic) NSString *tokenKey;
@property(nonatomic) GACAppCheckStorage *storage;
@end

@implementation GACAppCheckStorageTests

- (void)setUp {
  [super setUp];

  self.tokenKey = [self tokenKeyWithGoogleAppID:kGoogleAppID];
  self.storage = [[GACAppCheckStorage alloc] initWithTokenKey:self.tokenKey accessGroup:nil];
}

- (void)tearDown {
  self.storage = nil;
  [super tearDown];
}

- (void)testSetAndGetToken {
  GACAppCheckToken *tokenToStore = [[GACAppCheckToken alloc] initWithToken:@"token"
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
  GACAppCheckStorage *storage = [[GACAppCheckStorage alloc] initWithTokenKey:self.tokenKey
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
                        [GACAppCheckErrorUtil keychainErrorWithError:gulsKeychainError]);

  // 4. Verify storage mock.
  OCMVerifyAll(mockKeychainStorage);
}

- (void)testSetToken_KeychainError {
  // 1. Set up storage mock.
  id mockKeychainStorage = OCMClassMock([GULKeychainStorage class]);
  GACAppCheckStorage *storage = [[GACAppCheckStorage alloc] initWithTokenKey:self.tokenKey
                                                             keychainStorage:mockKeychainStorage
                                                                 accessGroup:nil];

  // 2. Create and expect keychain error.
  NSError *gulsKeychainError = [NSError errorWithDomain:@"com.guls.keychain" code:-1 userInfo:nil];
  OCMExpect([mockKeychainStorage setObject:[OCMArg any]
                                    forKey:[OCMArg any]
                               accessGroup:[OCMArg any]])
      .andReturn([FBLPromise resolvedWith:gulsKeychainError]);

  // 3. Set token and verify results.
  GACAppCheckToken *tokenToStore = [[GACAppCheckToken alloc] initWithToken:@"token"
                                                            expirationDate:[NSDate distantPast]
                                                            receivedAtDate:[NSDate date]];
  __auto_type getPromise = [storage setToken:tokenToStore];
  XCTAssert(FBLWaitForPromisesWithTimeout(0.5));
  XCTAssertNotNil(getPromise.error);
  XCTAssertEqualObjects(getPromise.error,
                        [GACAppCheckErrorUtil keychainErrorWithError:gulsKeychainError]);

  // 4. Verify storage mock.
  OCMVerifyAll(mockKeychainStorage);
}

- (void)testRemoveToken_KeychainError {
  // 1. Set up storage mock.
  id mockKeychainStorage = OCMClassMock([GULKeychainStorage class]);
  GACAppCheckStorage *storage = [[GACAppCheckStorage alloc] initWithTokenKey:self.tokenKey
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
                        [GACAppCheckErrorUtil keychainErrorWithError:gulsKeychainError]);

  // 4. Verify storage mock.
  OCMVerifyAll(mockKeychainStorage);
}

- (void)testSetTokenPerApp {
  // 1. Set token with a storage.
  GACAppCheckToken *tokenToStore = [[GACAppCheckToken alloc] initWithToken:@"token"
                                                            expirationDate:[NSDate distantPast]
                                                            receivedAtDate:[NSDate date]];

  FBLPromise *setPromise = [self.storage setToken:tokenToStore];
  XCTAssert(FBLWaitForPromisesWithTimeout(0.5));
  XCTAssertEqualObjects(setPromise.value, tokenToStore);
  XCTAssertNil(setPromise.error);

  // 2. Try to read the token with another storage.
  NSString *tokenKey =
      [self tokenKeyWithGoogleAppID:@"1:200000000000:ios:aaaaaaaaaaaaaaaaaaaaaaaa"];
  GACAppCheckStorage *storage2 = [[GACAppCheckStorage alloc] initWithTokenKey:tokenKey
                                                                  accessGroup:nil];
  __auto_type getPromise = [storage2 getToken];
  XCTAssert(FBLWaitForPromisesWithTimeout(0.5));
  XCTAssertNil(getPromise.value);
  XCTAssertNil(getPromise.error);
}

#pragma mark - Private Helpers

- (NSString *)tokenKeyWithGoogleAppID:(NSString *)googleAppID {
  return [NSString stringWithFormat:@"app_check_token.%@.%@", kAppName, googleAppID];
}

@end

#endif  // !TARGET_OS_MACCATALYST && !TARGET_OS_OSX

#endif  // !SWIFT_PACKAGE
