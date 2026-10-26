/*
 * Copyright 2017 Google
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

#import <OCMock/OCMock.h>
#import <XCTest/XCTest.h>

#import "FirebaseInstallations/Source/Library/Private/FirebaseInstallationsInternal.h"
#import "FirebaseMessaging/Sources/FIRMessagingConstants.h"
#import "FirebaseMessaging/Sources/Token/FIRMessagingAuthService.h"
#import "FirebaseMessaging/Sources/Token/FIRMessagingCheckinPreferences.h"
#import "FirebaseMessaging/Sources/Token/FIRMessagingCheckinStore.h"
#import "FirebaseMessaging/Sources/Token/FIRMessagingTokenInfo.h"
#import "FirebaseMessaging/Sources/Token/FIRMessagingTokenManager.h"
#import "FirebaseMessaging/Sources/Token/FIRMessagingTokenStore.h"
#import "FirebaseMessaging/Tests/UnitTests/FIRMessagingTestUtilities.h"

@interface FIRMessaging (ExposedForTest)

@property(nonatomic, readwrite, strong) FIRMessagingTokenManager *tokenManager;

@end

@interface FIRMessagingTokenManager (ExposedForTest)

- (void)didDeleteFCMScopedTokensForCheckin:(FIRMessagingCheckinPreferences *)checkin;

- (void)resetCredentialsIfNeeded;

@end

@interface FIRMessagingAuthService (ExposedForTest)

@property(nonatomic, readwrite, strong) FIRMessagingCheckinStore *checkinStore;

@end

@interface FIRMessagingTokenManagerTest : XCTestCase {
  FIRMessaging *_messaging;
  id _mockMessaging;
  id _mockPubSub;
  id _mockTokenManager;
  id _mockInstallations;
  id _mockCheckinStore;
  id _mockAuthService;
  id _mockTokenStore;
  FIRMessagingTestUtilities *_testUtil;
}

@end

@implementation FIRMessagingTokenManagerTest

- (void)setUp {
  [super setUp];
  // Create the messaging instance with all the necessary dependencies.
  NSUserDefaults *defaults =
      [[NSUserDefaults alloc] initWithSuiteName:kFIRMessagingDefaultsTestDomain];
  _testUtil = [[FIRMessagingTestUtilities alloc] initWithUserDefaults:defaults withRMQManager:NO];
  _mockMessaging = _testUtil.mockMessaging;
  _messaging = _testUtil.messaging;
  _mockTokenManager = _testUtil.mockTokenManager;
  _mockAuthService = OCMPartialMock(_messaging.tokenManager.authService);
  _mockCheckinStore = OCMPartialMock(_messaging.tokenManager.authService.checkinStore);
}

- (void)tearDown {
  [_mockTokenStore stopMocking];
  [_mockCheckinStore stopMocking];
  [_mockAuthService stopMocking];
  [_testUtil cleanupAfterTest:self];
  _messaging = nil;
  [[[NSUserDefaults alloc] initWithSuiteName:kFIRMessagingDefaultsTestDomain]
      removePersistentDomainForName:kFIRMessagingDefaultsTestDomain];
  [super tearDown];
}

- (void)testTokenChangeMethod {
  NSString *oldToken = nil;
  NSString *newToken = @"new_token";
  XCTAssertTrue([_messaging.tokenManager hasTokenChangedFromOldToken:oldToken toNewToken:newToken]);

  oldToken = @"old_token";
  newToken = nil;
  XCTAssertTrue([_messaging.tokenManager hasTokenChangedFromOldToken:oldToken toNewToken:newToken]);

  oldToken = @"old_token";
  newToken = @"new_token";
  XCTAssertTrue([_messaging.tokenManager hasTokenChangedFromOldToken:oldToken toNewToken:newToken]);

  oldToken = @"The_same_token";
  newToken = @"The_same_token";
  XCTAssertFalse([_messaging.tokenManager hasTokenChangedFromOldToken:oldToken
                                                           toNewToken:newToken]);

  oldToken = nil;
  newToken = nil;
  XCTAssertFalse([_messaging.tokenManager hasTokenChangedFromOldToken:oldToken
                                                           toNewToken:newToken]);

  oldToken = @"";
  newToken = @"";
  XCTAssertFalse([_messaging.tokenManager hasTokenChangedFromOldToken:oldToken
                                                           toNewToken:newToken]);

  oldToken = nil;
  newToken = @"";
  XCTAssertFalse([_messaging.tokenManager hasTokenChangedFromOldToken:oldToken
                                                           toNewToken:newToken]);

  oldToken = @"";
  newToken = nil;
  XCTAssertFalse([_messaging.tokenManager hasTokenChangedFromOldToken:oldToken
                                                           toNewToken:newToken]);
}

- (void)testResetCredentialsWithNoCachedCheckin {
  id completionArg = [OCMArg invokeBlockWithArgs:[NSNull null], nil];
  OCMReject([_mockCheckinStore removeCheckinPreferencesWithHandler:completionArg]);
  // Always setting up stub after expect.
  OCMStub([_mockAuthService checkinPreferences]).andReturn(nil);

  [_messaging.tokenManager resetCredentialsIfNeeded];

  OCMVerifyAll(_mockCheckinStore);
}

- (void)testResetCredentialsWithoutFreshInstall {
  id completionArg = [OCMArg invokeBlockWithArgs:[NSNull null], nil];
  OCMReject([_mockCheckinStore removeCheckinPreferencesWithHandler:completionArg]);
  // Always setting up stub after expect.
  OCMStub([_mockAuthService hasCheckinPlist]).andReturn(YES);

  [_messaging.tokenManager resetCredentialsIfNeeded];

  OCMVerifyAll(_mockCheckinStore);
}

- (void)testResetCredentialsWithFreshInstall {
  FIRMessagingCheckinPreferences *checkinPreferences =
      [[FIRMessagingCheckinPreferences alloc] initWithDeviceID:@"test-auth-id"
                                                   secretToken:@"test-secret"];
  // Expect checkin is removed if it's a fresh install.
  id completionArg = [OCMArg invokeBlockWithArgs:[NSNull null], nil];
  OCMExpect([_mockCheckinStore removeCheckinPreferencesWithHandler:completionArg]);
  // Always setting up stub after expect.
  OCMStub([_mockAuthService checkinPreferences]).andReturn(checkinPreferences);
  // Plist file doesn't exist, meaning this is a fresh install.
  OCMStub([_mockCheckinStore hasCheckinPlist]).andReturn(NO);
  // Expect reset operation but do nothing to avoid flakes due to delayed operation queue.
  OCMExpect(
      [_mockTokenManager didDeleteFCMScopedTokensForCheckin:[OCMArg isEqual:checkinPreferences]])
      .andDo(nil);

  [_messaging.tokenManager resetCredentialsIfNeeded];
  OCMVerifyAll(_mockCheckinStore);
}

- (void)testTokenAndRequestIfNotExistCallsTokenWithAuthorizedEntityWhenCachedTokenIsV4 {
  OCMStub([_mockMessaging isInstallationIdEnabled]).andReturn(YES);

  _messaging.tokenManager.fcmSenderID = @"123456789123";

  FIRMessagingTokenInfo *cachedTokenInfo =
      [[FIRMessagingTokenInfo alloc] initWithAuthorizedEntity:@"123456789123"
                                                        scope:kFIRMessagingDefaultTokenScope
                                                        token:@"old-v4-token"
                                                   appVersion:@"1.0"
                                                firebaseAppID:@"app-id"
                                                    tokenType:@"V4"];

  OCMStub([_mockTokenManager cachedTokenInfoWithAuthorizedEntity:@"123456789123"
                                                           scope:kFIRMessagingDefaultTokenScope])
      .andReturn(cachedTokenInfo);

  OCMExpect([_mockTokenManager tokenWithAuthorizedEntity:@"123456789123"
                                                   scope:kFIRMessagingDefaultTokenScope
                                                 options:OCMOCK_ANY
                                                 handler:OCMOCK_ANY]);

  NSString *token = [_messaging.tokenManager tokenAndRequestIfNotExist];

  XCTAssertNil(token);
  OCMVerifyAll(_mockTokenManager);
}

- (void)testTokenAndRequestIfNotExistReturnsCachedV4TokenWhenInstallationIdDisabled {
  OCMStub([_mockMessaging isInstallationIdEnabled]).andReturn(NO);

  _messaging.tokenManager.fcmSenderID = @"123456789123";

  FIRMessagingTokenInfo *cachedTokenInfo =
      [[FIRMessagingTokenInfo alloc] initWithAuthorizedEntity:@"123456789123"
                                                        scope:kFIRMessagingDefaultTokenScope
                                                        token:@"cached-v4-token"
                                                   appVersion:@"1.0"
                                                firebaseAppID:@"app-id"
                                                    tokenType:@"V4"];

  OCMStub([_mockTokenManager cachedTokenInfoWithAuthorizedEntity:@"123456789123"
                                                           scope:kFIRMessagingDefaultTokenScope])
      .andReturn(cachedTokenInfo);

  [[_mockTokenManager reject] tokenWithAuthorizedEntity:OCMOCK_ANY
                                                  scope:OCMOCK_ANY
                                                options:OCMOCK_ANY
                                                handler:OCMOCK_ANY];

  NSString *token = [_messaging.tokenManager tokenAndRequestIfNotExist];

  XCTAssertEqualObjects(token, @"cached-v4-token");
  // defaultFCMToken should not be set yet so that updateDefaultFCMToken can detect the change.
  XCTAssertNil([_messaging.tokenManager defaultFCMToken]);
  OCMVerifyAll(_mockTokenManager);
}

- (void)testTokenAndRequestIfNotExistReturnsCachedFIDWhenInstallationIdEnabled {
  OCMStub([_mockMessaging isInstallationIdEnabled]).andReturn(YES);

  _messaging.tokenManager.fcmSenderID = @"123456789123";

  FIRMessagingTokenInfo *cachedTokenInfo =
      [[FIRMessagingTokenInfo alloc] initWithAuthorizedEntity:@"123456789123"
                                                        scope:kFIRMessagingDefaultTokenScope
                                                        token:@"fake-cached-fid"
                                                   appVersion:@"1.0"
                                                firebaseAppID:@"app-id"
                                                    tokenType:@"FID"];

  OCMStub([_mockTokenManager cachedTokenInfoWithAuthorizedEntity:@"123456789123"
                                                           scope:kFIRMessagingDefaultTokenScope])
      .andReturn(cachedTokenInfo);

  [[_mockTokenManager reject] tokenWithAuthorizedEntity:OCMOCK_ANY
                                                  scope:OCMOCK_ANY
                                                options:OCMOCK_ANY
                                                handler:OCMOCK_ANY];

  NSString *token = [_messaging.tokenManager tokenAndRequestIfNotExist];

  XCTAssertEqualObjects(token, @"fake-cached-fid");
  // defaultFCMToken should not be set yet so that updateDefaultFCMToken can detect the change.
  XCTAssertNil([_messaging.tokenManager defaultFCMToken]);
  OCMVerifyAll(_mockTokenManager);
}

#pragma mark - setAPNSToken:withUserInfo:

- (FIRMessagingTokenStore *)tokenStore {
  return [_messaging.tokenManager valueForKey:@"_tokenStore"];
}

/// Saves a default token that was fetched with the given sandbox APNs token.
- (void)cacheDefaultTokenWithSandboxAPNSToken:(NSData *)APNSToken {
  FIRMessagingTokenInfo *tokenInfo =
      [[FIRMessagingTokenInfo alloc] initWithAuthorizedEntity:@"123456789123"
                                                        scope:kFIRMessagingDefaultTokenScope
                                                        token:@"cached-token"
                                                   appVersion:@"1.0"
                                                firebaseAppID:@"app-id"
                                                    tokenType:@"V4"];
  tokenInfo.APNSInfo = [[FIRMessagingAPNSInfo alloc] initWithDeviceToken:APNSToken isSandbox:YES];
  [[self tokenStore] saveTokenInfo:tokenInfo handler:nil];
}

/// Sets a sandbox APNs token, which is what the simulator always uses, so that the tests behave the
/// same on all platforms.
- (void)setSandboxAPNSToken:(NSData *)APNSToken {
  [_messaging.tokenManager
      setAPNSToken:APNSToken
      withUserInfo:@{kFIRMessagingAPNSTokenType : @(FIRMessagingAPNSTokenTypeSandbox)}];
}

/// Matches token options that contain the given sandbox APNs token.
- (id)tokenOptionsWithSandboxAPNSToken:(NSData *)APNSToken {
  return [OCMArg checkWithBlock:^BOOL(NSDictionary *options) {
    return [options[kFIRMessagingTokenOptionsAPNSKey] isEqual:APNSToken] &&
           [options[kFIRMessagingTokenOptionsAPNSIsSandboxKey] isEqual:@YES];
  }];
}

- (void)testSetAPNSTokenReadsCachedTokensOnceAndFetchesDefaultTokenWhenNoTokenIsCached {
  NSData *APNSToken = [@"fakeAPNSToken" dataUsingEncoding:NSUTF8StringEncoding];
  _mockTokenStore = OCMPartialMock([self tokenStore]);
  // Save the installation ID handler instead of calling it, to check what happens synchronously.
  __block FIRInstallationsIDHandler installationIDHandler;
  OCMStub([(FIRInstallations *)_testUtil.mockInstallations
      installationIDWithCompletion:[OCMArg checkWithBlock:^BOOL(id handler) {
        installationIDHandler = [handler copy];
        return YES;
      }]]);
  OCMExpect([_mockTokenManager
                tokenWithAuthorizedEntity:@"123456789123"
                                    scope:kFIRMessagingDefaultTokenScope
                                  options:[self tokenOptionsWithSandboxAPNSToken:APNSToken]
                                  handler:OCMOCK_ANY])
      .andDo(nil);

  [self setSandboxAPNSToken:APNSToken];

  // The cached tokens are read from the keychain only once before `setAPNSToken` returns.
  OCMVerify(times(1), [_mockTokenStore cachedTokenInfos]);
  // No token is cached, so the default token is fetched once the installation ID is available.
  XCTAssertNotNil(installationIDHandler);
  installationIDHandler(@"fake-fid", nil);
  OCMVerifyAll(_mockTokenManager);
  // The callback reads the cached tokens again, since they may have changed by then.
  OCMVerify(times(2), [_mockTokenStore cachedTokenInfos]);
}

- (void)testSetAPNSTokenReadsCachedTokensOnceAndKeepsTokenCachedWithSameAPNSToken {
  // This is the usual case at app launch: the APNs token is the same as when the cached token was
  // fetched.
  NSData *APNSToken = [@"fakeAPNSToken" dataUsingEncoding:NSUTF8StringEncoding];
  [self cacheDefaultTokenWithSandboxAPNSToken:APNSToken];
  _mockTokenStore = OCMPartialMock([self tokenStore]);

  [self setSandboxAPNSToken:APNSToken];

  // The cached tokens are read from the keychain only once.
  OCMVerify(times(1), [_mockTokenStore cachedTokenInfos]);
  // The cached token is still valid, so it's kept and nothing is fetched.
  XCTAssertNotNil([[self tokenStore] tokenInfoWithAuthorizedEntity:@"123456789123"
                                                             scope:kFIRMessagingDefaultTokenScope]);
  OCMVerify(never(), [(FIRInstallations *)_testUtil.mockInstallations
                         installationIDWithCompletion:OCMOCK_ANY]);
}

- (void)testSetAPNSTokenReadsCachedTokensOnceAndRefetchesTokenInvalidatedByAPNSTokenChange {
  NSData *oldAPNSToken = [@"oldAPNSToken" dataUsingEncoding:NSUTF8StringEncoding];
  NSData *newAPNSToken = [@"newAPNSToken" dataUsingEncoding:NSUTF8StringEncoding];
  [self cacheDefaultTokenWithSandboxAPNSToken:oldAPNSToken];
  _mockTokenStore = OCMPartialMock([self tokenStore]);
  // Save the installation ID handler instead of calling it, to check what happens synchronously.
  __block FIRInstallationsIDHandler installationIDHandler;
  OCMStub([(FIRInstallations *)_testUtil.mockInstallations
      installationIDWithCompletion:[OCMArg checkWithBlock:^BOOL(id handler) {
        installationIDHandler = [handler copy];
        return YES;
      }]]);
  OCMExpect(
      [_mockTokenManager
          fetchNewTokenWithAuthorizedEntity:@"123456789123"
                                      scope:kFIRMessagingDefaultTokenScope
                                 instanceID:@"fake-fid"
                                    options:[self tokenOptionsWithSandboxAPNSToken:newAPNSToken]
                                    handler:OCMOCK_ANY])
      .andDo(nil);
  // No token is left after the invalidation, so the default token is requested too. Don't let that
  // request run.
  OCMStub([_mockTokenManager tokenWithAuthorizedEntity:OCMOCK_ANY
                                                 scope:OCMOCK_ANY
                                               options:OCMOCK_ANY
                                               handler:OCMOCK_ANY])
      .andDo(nil);

  [self setSandboxAPNSToken:newAPNSToken];

  // The cached tokens are read from the keychain only once before `setAPNSToken` returns.
  OCMVerify(times(1), [_mockTokenStore cachedTokenInfos]);
  // The token fetched with the old APNs token is invalidated, and re-fetched with the new one once
  // the installation ID is available.
  XCTAssertNil([[self tokenStore] tokenInfoWithAuthorizedEntity:@"123456789123"
                                                          scope:kFIRMessagingDefaultTokenScope]);
  XCTAssertNotNil(installationIDHandler);
  installationIDHandler(@"fake-fid", nil);
  OCMVerifyAll(_mockTokenManager);
  // The callback reads the cached tokens again, since they may have changed by then.
  OCMVerify(times(2), [_mockTokenStore cachedTokenInfos]);
}

@end
