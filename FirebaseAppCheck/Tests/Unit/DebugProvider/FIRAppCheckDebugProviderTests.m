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
#import <XCTest/XCTest.h>

#import <OCMock/OCMock.h>

#import "FirebaseAppCheck/Sources/Core/FIRApp+AppCheck.h"
#import "FirebaseAppCheck/Sources/Core/FIRAppCheckToken+Internal.h"
#import "FirebaseAppCheck/Sources/Core/FIRHeartbeatLogger+AppCheck.h"
#import "FirebaseAppCheck/Sources/DebugProvider/FIRAppCheckDebugTokenConfigStore.h"
#import "FirebaseAppCheck/Sources/Public/FirebaseAppCheck/FIRAppCheckDebugProvider.h"

#import "FirebaseCore/Extension/FirebaseCoreInternal.h"

static NSString *const kAppName = @"test_app_name";
static NSString *const kAppID = @"test_app_id";
static NSString *const kAPIKey = @"test_api_key";
static NSString *const kProjectID = @"test_project_id";
static NSString *const kProjectNumber = @"123456789";

@interface FIRAppCheckDebugProvider (Tests)

- (instancetype)initWithDebugProvider:(GACAppCheckDebugProvider *)debugProvider
                            projectID:(nullable NSString *)projectID
                          googleAppID:(NSString *)googleAppID;
- (nullable NSString *)debugTokenExchangeFailureMessageForError:(NSError *)error;

@property(nonatomic, readonly, copy, nullable) NSString *projectID;
@property(nonatomic, readonly, copy) NSString *googleAppID;
@property(nonatomic, readonly) GACAppCheckDebugTokenSource debugTokenSource;

@end

@interface FIRAppCheckDebugProviderTests : XCTestCase

@property(nonatomic, copy) NSString *resourceName;
@property(nonatomic) id debugProviderMock;
@property(nonatomic) FIRAppCheckDebugProvider *provider;

@end

@implementation FIRAppCheckDebugProviderTests

- (void)setUp {
  self.resourceName = [NSString stringWithFormat:@"projects/%@/apps/%@", kProjectID, kAppID];
  self.debugProviderMock = OCMStrictClassMock([GACAppCheckDebugProvider class]);
  [self expectDebugTokenSource:GACAppCheckDebugTokenSourceLocal];
  self.provider = [[FIRAppCheckDebugProvider alloc] initWithDebugProvider:self.debugProviderMock
                                                                projectID:nil
                                                              googleAppID:kAppID];
}

- (void)tearDown {
  self.provider = nil;
  [self.debugProviderMock stopMocking];
  self.debugProviderMock = nil;
}

#pragma mark - Initialization

- (void)testInitWithValidApp {
  FIROptions *options = [[FIROptions alloc] initWithGoogleAppID:kAppID GCMSenderID:kProjectNumber];
  options.APIKey = kAPIKey;
  options.projectID = kProjectID;
  FIRApp *app = [[FIRApp alloc] initInstanceWithName:kAppName options:options];
  // The following disables automatic token refresh, which could interfere with tests.
  app.dataCollectionDefaultEnabled = NO;

  FIRAppCheckDebugProvider *provider = [[FIRAppCheckDebugProvider alloc] initWithApp:app];
  XCTAssertNotNil(provider);
  XCTAssertEqualObjects(provider.projectID, kProjectID);
  XCTAssertEqualObjects(provider.googleAppID, kAppID);
}

- (void)testInitWithDebugProvider {
  XCTAssertNil(self.provider.projectID);
  XCTAssertEqualObjects(self.provider.googleAppID, kAppID);
  XCTAssertEqual(self.provider.debugTokenSource, GACAppCheckDebugTokenSourceLocal);
}

- (void)testInitWithIncompleteApp {
  FIROptions *options = [[FIROptions alloc] initWithGoogleAppID:kAppID GCMSenderID:kProjectNumber];
  options.projectID = kProjectID;
  FIRApp *missingAPIKeyApp = [[FIRApp alloc] initInstanceWithName:kAppName options:options];
  // The following disables automatic token refresh, which could interfere with tests.
  missingAPIKeyApp.dataCollectionDefaultEnabled = NO;

  XCTAssertNil([[FIRAppCheckDebugProvider alloc] initWithApp:missingAPIKeyApp]);

  options.projectID = nil;
  options.APIKey = kAPIKey;
  FIRApp *missingProjectIDApp = [[FIRApp alloc] initInstanceWithName:kAppName options:options];
  // The following disables automatic token refresh, which could interfere with tests.
  missingProjectIDApp.dataCollectionDefaultEnabled = NO;
  XCTAssertNil([[FIRAppCheckDebugProvider alloc] initWithApp:missingProjectIDApp]);
}

#pragma mark - Debug token source

- (void)testInitWithConfigStoreDebugTokenLogsAttribution {
  [self expectDebugTokenSource:GACAppCheckDebugTokenSourceProvided];

  FIRAppCheckDebugProvider *provider =
      [[FIRAppCheckDebugProvider alloc] initWithDebugProvider:self.debugProviderMock
                                                    projectID:kProjectID
                                                  googleAppID:kAppID];

  XCTAssertEqual(provider.debugTokenSource, GACAppCheckDebugTokenSourceProvided);
  // `localDebugToken` is never stubbed, so the strict mock fails if the local token is logged.
  OCMVerifyAll(self.debugProviderMock);
}

- (void)testInitWithEnvironmentVariableDebugTokenDoesNotLogLocalToken {
  [self expectDebugTokenSource:GACAppCheckDebugTokenSourceEnvironmentVariable];

  FIRAppCheckDebugProvider *provider =
      [[FIRAppCheckDebugProvider alloc] initWithDebugProvider:self.debugProviderMock
                                                    projectID:kProjectID
                                                  googleAppID:kAppID];

  XCTAssertEqual(provider.debugTokenSource, GACAppCheckDebugTokenSourceEnvironmentVariable);
  // `localDebugToken` is never stubbed, so the strict mock fails if an unused local token is
  // generated or logged.
  OCMVerifyAll(self.debugProviderMock);
}

- (void)testInitWithLocalDebugTokenLogsLocalToken {
  [self expectDebugTokenSource:GACAppCheckDebugTokenSourceLocal];
  OCMExpect([self.debugProviderMock localDebugToken]).andReturn(@"local_token");

  FIRAppCheckDebugProvider *provider =
      [[FIRAppCheckDebugProvider alloc] initWithDebugProvider:self.debugProviderMock
                                                    projectID:kProjectID
                                                  googleAppID:kAppID];

  XCTAssertEqual(provider.debugTokenSource, GACAppCheckDebugTokenSourceLocal);
  OCMVerifyAll(self.debugProviderMock);
}

- (void)testGetTokenAPIErrorWithConfigStoreDebugTokenDoesNotLogLocalToken {
  FIRAppCheckDebugProvider *provider =
      [self providerWithDebugTokenSource:GACAppCheckDebugTokenSourceProvided projectID:kProjectID];
  NSError *expectedError = [NSError errorWithDomain:@"testGetTokenAPIError" code:-1 userInfo:nil];
  OCMExpect([self.debugProviderMock
      getTokenWithCompletion:([OCMArg invokeBlockWithArgs:[NSNull null], expectedError, nil])]);
  __block BOOL handlerCalled = NO;

  [provider getTokenWithCompletion:^(FIRAppCheckToken *_Nullable token, NSError *_Nullable error) {
    handlerCalled = YES;
    XCTAssertNil(token);
    XCTAssertEqualObjects(error, expectedError);
  }];

  XCTAssertTrue(handlerCalled);
  // `localDebugToken` is never stubbed, so the strict mock fails if the fallback message is logged.
  OCMVerifyAll(self.debugProviderMock);
}

- (void)testGetLimitedUseTokenAPIErrorWithConfigStoreDebugTokenDoesNotLogLocalToken {
  FIRAppCheckDebugProvider *provider =
      [self providerWithDebugTokenSource:GACAppCheckDebugTokenSourceProvided projectID:kProjectID];
  NSError *expectedError = [NSError errorWithDomain:@"testGetLimitedUseTokenAPIError"
                                               code:-1
                                           userInfo:nil];
  OCMExpect([self.debugProviderMock
      getLimitedUseTokenWithCompletion:([OCMArg invokeBlockWithArgs:[NSNull null], expectedError,
                                                                    nil])]);
  __block BOOL handlerCalled = NO;

  [provider getLimitedUseTokenWithCompletion:^(FIRAppCheckToken *_Nullable token,
                                               NSError *_Nullable error) {
    handlerCalled = YES;
    XCTAssertNil(token);
    XCTAssertEqualObjects(error, expectedError);
  }];

  XCTAssertTrue(handlerCalled);
  // `localDebugToken` is never stubbed, so the strict mock fails if the fallback message is logged.
  OCMVerifyAll(self.debugProviderMock);
}

- (void)testGetTokenAPIErrorWithEnvironmentVariableDebugTokenDoesNotLogLocalToken {
  FIRAppCheckDebugProvider *provider =
      [self providerWithDebugTokenSource:GACAppCheckDebugTokenSourceEnvironmentVariable
                               projectID:kProjectID];
  NSError *expectedError = [NSError errorWithDomain:@"testGetTokenAPIError" code:-1 userInfo:nil];
  OCMExpect([self.debugProviderMock
      getTokenWithCompletion:([OCMArg invokeBlockWithArgs:[NSNull null], expectedError, nil])]);
  __block BOOL handlerCalled = NO;

  [provider getTokenWithCompletion:^(FIRAppCheckToken *_Nullable token, NSError *_Nullable error) {
    handlerCalled = YES;
    XCTAssertNil(token);
    XCTAssertEqualObjects(error, expectedError);
  }];

  XCTAssertTrue(handlerCalled);
  // `localDebugToken` is never stubbed, so the strict mock fails if the fallback message is logged.
  OCMVerifyAll(self.debugProviderMock);
}

#pragma mark - Exchange failure messages

- (void)testConfigStoreExchangeFailureMessageSuggestsForceCreateAndRelaunch {
  FIRAppCheckDebugProvider *provider =
      [self providerWithDebugTokenSource:GACAppCheckDebugTokenSourceProvided projectID:kProjectID];
  NSError *error = [NSError errorWithDomain:@"testDomain"
                                       code:-1
                                   userInfo:@{NSLocalizedDescriptionKey : @"Permission denied"}];

  NSString *message = [provider debugTokenExchangeFailureMessageForError:error];

  XCTAssertTrue([message containsString:@"~/.config/configstore/firebase-appcheck.json"]);
  XCTAssertTrue([message containsString:@"Permission denied"]);
  NSString *expectedCommand =
      [NSString stringWithFormat:@"`firebase appcheck:debugtokens:create --force --project %@ "
                                 @"--app %@`",
                                 kProjectID, kAppID];
  XCTAssertTrue([message containsString:expectedCommand], @"%@", message);
  XCTAssertTrue([message containsString:@"relaunch the app"], @"%@", message);
}

- (void)testConfigStoreExchangeFailureMessageOmitsMissingProjectID {
  FIRAppCheckDebugProvider *provider =
      [self providerWithDebugTokenSource:GACAppCheckDebugTokenSourceProvided projectID:nil];
  NSError *error = [NSError errorWithDomain:@"testDomain" code:-1 userInfo:nil];

  NSString *message = [provider debugTokenExchangeFailureMessageForError:error];

  XCTAssertFalse([message containsString:@"--project"], @"%@", message);
  XCTAssertFalse([message containsString:@"(null)"], @"%@", message);
  NSString *expectedCommand = [NSString
      stringWithFormat:@"`firebase appcheck:debugtokens:create --force --app %@`", kAppID];
  XCTAssertTrue([message containsString:expectedCommand], @"%@", message);
}

- (void)testConfigStoreExchangeFailureMessagePrefersFailureReason {
  FIRAppCheckDebugProvider *provider =
      [self providerWithDebugTokenSource:GACAppCheckDebugTokenSourceProvided projectID:kProjectID];
  NSError *error = [NSError
      errorWithDomain:@"testDomain"
                 code:-1
             userInfo:@{NSLocalizedFailureReasonErrorKey : @"The server responded with an error"}];

  NSString *message = [provider debugTokenExchangeFailureMessageForError:error];

  XCTAssertTrue([message containsString:@": The server responded with an error"], @"%@", message);
  XCTAssertFalse([message containsString:@"couldn’t be completed"], @"%@", message);
}

- (void)testEnvironmentVariableExchangeFailureMessageNamesVariablesWithoutForce {
  FIRAppCheckDebugProvider *provider =
      [self providerWithDebugTokenSource:GACAppCheckDebugTokenSourceEnvironmentVariable
                               projectID:kProjectID];
  NSError *error = [NSError errorWithDomain:@"testDomain"
                                       code:-1
                                   userInfo:@{NSLocalizedDescriptionKey : @"Permission denied"}];

  NSString *message = [provider debugTokenExchangeFailureMessageForError:error];

  XCTAssertTrue([message containsString:@"`AppCheckDebugToken`"], @"%@", message);
  XCTAssertTrue([message containsString:@"`FIRAAppCheckDebugToken`"], @"%@", message);
  XCTAssertTrue([message containsString:@"Permission denied"], @"%@", message);
  NSString *expectedCommand =
      [NSString stringWithFormat:@"`firebase appcheck:debugtokens:create <token> --project %@ "
                                 @"--app %@`",
                                 kProjectID, kAppID];
  XCTAssertTrue([message containsString:expectedCommand], @"%@", message);
  // Provisioning a new config store token would not help while the environment variable wins.
  XCTAssertFalse([message containsString:@"--force"], @"%@", message);
  XCTAssertFalse([message containsString:@"firebase-appcheck.json"], @"%@", message);
}

- (void)testExchangeFailureMessageIsNilWhenServerUnreachable {
  NSError *error = [NSError errorWithDomain:GACAppCheckErrors.errorDomain
                                       code:GACAppCheckErrorCodeServerUnreachable
                                   userInfo:nil];
  FIRAppCheckDebugProvider *configStoreProvider =
      [self providerWithDebugTokenSource:GACAppCheckDebugTokenSourceProvided projectID:kProjectID];
  FIRAppCheckDebugProvider *environmentVariableProvider =
      [self providerWithDebugTokenSource:GACAppCheckDebugTokenSourceEnvironmentVariable
                               projectID:kProjectID];

  NSString *configStoreMessage =
      [configStoreProvider debugTokenExchangeFailureMessageForError:error];
  NSString *environmentVariableMessage =
      [environmentVariableProvider debugTokenExchangeFailureMessageForError:error];

  XCTAssertNil(configStoreMessage);
  XCTAssertNil(environmentVariableMessage);
}

#if TARGET_OS_SIMULATOR
/// Exercises `-initWithApp:` end to end, without mocks: config store lookup by each app's Google
/// App ID, through to the token used by the App Check Core debug provider.
- (void)testInitWithAppUsesConfigStoreDebugTokenForEachApp {
  NSString *otherAppID = @"other_test_app_id";
  NSURL *hostHomeURL = [self temporaryHostHomeWithTokens:@{
    kAppID : @"config_store_token",
    otherAppID : @"other_config_store_token",
  }];
  [self setEnvironmentVariable:@"SIMULATOR_HOST_HOME" value:hostHomeURL.path];
  [self setEnvironmentVariable:@"AppCheckDebugToken" value:nil];
  [self setEnvironmentVariable:@"FIRAAppCheckDebugToken" value:nil];
  FIRApp *app = [self appWithName:kAppName googleAppID:kAppID];
  FIRApp *otherApp = [self appWithName:@"other_test_app_name" googleAppID:otherAppID];

  FIRAppCheckDebugProvider *provider = [[FIRAppCheckDebugProvider alloc] initWithApp:app];
  FIRAppCheckDebugProvider *otherProvider = [[FIRAppCheckDebugProvider alloc] initWithApp:otherApp];

  XCTAssertEqualObjects([provider currentDebugToken], @"config_store_token");
  XCTAssertEqual(provider.debugTokenSource, GACAppCheckDebugTokenSourceProvided);
  XCTAssertEqualObjects([otherProvider currentDebugToken], @"other_config_store_token");
  XCTAssertEqual(otherProvider.debugTokenSource, GACAppCheckDebugTokenSourceProvided);
}

/// An environment variable wins over the config store even when both hold the same token, so the
/// token must not be attributed to the config store.
- (void)testInitWithAppAttributesMatchingEnvironmentVariableToEnvironment {
  NSURL *hostHomeURL = [self temporaryHostHomeWithTokens:@{kAppID : @"same_token"}];
  [self setEnvironmentVariable:@"SIMULATOR_HOST_HOME" value:hostHomeURL.path];
  [self setEnvironmentVariable:@"AppCheckDebugToken" value:@"same_token"];
  [self setEnvironmentVariable:@"FIRAAppCheckDebugToken" value:nil];
  FIRApp *app = [self appWithName:kAppName googleAppID:kAppID];

  FIRAppCheckDebugProvider *provider = [[FIRAppCheckDebugProvider alloc] initWithApp:app];

  XCTAssertEqualObjects([provider currentDebugToken], @"same_token");
  XCTAssertEqual(provider.debugTokenSource, GACAppCheckDebugTokenSourceEnvironmentVariable);
}
#endif  // TARGET_OS_SIMULATOR

#pragma mark - Current Debug token

- (void)testCurrentTokenShim {
  NSString *currentToken = @"debug_token";
  OCMExpect([self.debugProviderMock currentDebugToken]).andReturn(currentToken);

  XCTAssertEqualObjects([self.provider currentDebugToken], currentToken);

  OCMVerifyAll(self.debugProviderMock);
}

#pragma mark - Local Debug Token

- (void)testLocalDebugToken {
  NSString *localToken = @"TEST_LocalDebugToken";
  OCMExpect([self.debugProviderMock localDebugToken]).andReturn(localToken);

  XCTAssertEqualObjects([self.provider localDebugToken], localToken);

  OCMVerifyAll(self.debugProviderMock);
}

#pragma mark - Debug token to FAC token exchange

- (void)testGetTokenSuccess {
  // 1. Stub internal debug provider.
  GACAppCheckToken *validInternalToken = [[GACAppCheckToken alloc] initWithToken:@"valid_token"
                                                                  expirationDate:[NSDate date]
                                                                  receivedAtDate:[NSDate date]];
  OCMExpect([self.debugProviderMock
      getTokenWithCompletion:([OCMArg
                                 invokeBlockWithArgs:validInternalToken, [NSNull null], nil])]);

  // 2. Validate get token.
  [self.provider
      getTokenWithCompletion:^(FIRAppCheckToken *_Nullable token, NSError *_Nullable error) {
        XCTAssertEqualObjects(token.token, validInternalToken.token);
        XCTAssertEqualObjects(token.expirationDate, validInternalToken.expirationDate);
        XCTAssertEqualObjects(token.receivedAtDate, validInternalToken.receivedAtDate);
        XCTAssertNil(error);
      }];

  // 3. Verify mock debug provider.
  OCMVerifyAll(self.debugProviderMock);
}

- (void)testGetTokenAPIError {
  // 1. Stub internal debug provider.
  NSError *expectedError = [NSError errorWithDomain:@"testGetTokenAPIError" code:-1 userInfo:nil];
  OCMExpect([self.debugProviderMock
      getTokenWithCompletion:([OCMArg invokeBlockWithArgs:[NSNull null], expectedError, nil])]);

  // 2. Validate get token.
  [self.provider
      getTokenWithCompletion:^(FIRAppCheckToken *_Nullable token, NSError *_Nullable error) {
        XCTAssertNil(token);
        XCTAssertEqualObjects(error, expectedError);
      }];

  // 3. Verify mock debug provider.
  OCMVerifyAll(self.debugProviderMock);
}

#pragma mark - Limited-Use Token

- (void)testGetLimitedUseTokenSuccess {
  GACAppCheckToken *validInternalToken = [[GACAppCheckToken alloc] initWithToken:@"TEST_ValidToken"
                                                                  expirationDate:[NSDate date]
                                                                  receivedAtDate:[NSDate date]];
  OCMExpect([self.debugProviderMock
      getLimitedUseTokenWithCompletion:([OCMArg invokeBlockWithArgs:validInternalToken,
                                                                    [NSNull null], nil])]);

  [self.provider getLimitedUseTokenWithCompletion:^(FIRAppCheckToken *_Nullable token,
                                                    NSError *_Nullable error) {
    XCTAssertEqualObjects(token.token, validInternalToken.token);
    XCTAssertEqualObjects(token.expirationDate, validInternalToken.expirationDate);
    XCTAssertEqualObjects(token.receivedAtDate, validInternalToken.receivedAtDate);
    XCTAssertNil(error);
  }];

  OCMVerifyAll(self.debugProviderMock);
}

- (void)testGetLimitedUseTokenProviderError {
  NSError *expectedError = [NSError errorWithDomain:@"TEST_LimitedUseToken_Error"
                                               code:-1
                                           userInfo:nil];
  OCMExpect([self.debugProviderMock
      getLimitedUseTokenWithCompletion:([OCMArg invokeBlockWithArgs:[NSNull null], expectedError,
                                                                    nil])]);

  [self.provider getLimitedUseTokenWithCompletion:^(FIRAppCheckToken *_Nullable token,
                                                    NSError *_Nullable error) {
    XCTAssertNil(token);
    XCTAssertIdentical(error, expectedError);
  }];

  OCMVerifyAll(self.debugProviderMock);
}

#pragma mark - Helpers

/// Returns an app with complete options for token exchange and automatic token refresh disabled.
- (FIRApp *)appWithName:(NSString *)name googleAppID:(NSString *)googleAppID {
  FIROptions *options = [[FIROptions alloc] initWithGoogleAppID:googleAppID
                                                    GCMSenderID:kProjectNumber];
  options.APIKey = kAPIKey;
  options.projectID = kProjectID;
  FIRApp *app = [[FIRApp alloc] initInstanceWithName:name options:options];
  // The following disables automatic token refresh, which could interfere with tests.
  app.dataCollectionDefaultEnabled = NO;
  return app;
}

/// Creates a temporary host home directory containing a config store with the given tokens,
/// removed when the test finishes.
- (NSURL *)temporaryHostHomeWithTokens:(NSDictionary<NSString *, NSString *> *)tokens {
  NSURL *hostHomeURL = [[NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES]
      URLByAppendingPathComponent:[NSUUID UUID].UUIDString
                      isDirectory:YES];
  NSURL *fileURL =
      [hostHomeURL URLByAppendingPathComponent:FIRAppCheckDebugTokenConfigStore.relativePath
                                   isDirectory:NO];
  NSError *error;
  XCTAssertTrue(
      [[NSFileManager defaultManager] createDirectoryAtURL:fileURL.URLByDeletingLastPathComponent
                               withIntermediateDirectories:YES
                                                attributes:nil
                                                     error:&error],
      @"%@", error);
  NSData *data = [NSJSONSerialization dataWithJSONObject:@{@"tokens" : tokens}
                                                 options:0
                                                   error:&error];
  XCTAssertTrue([data writeToURL:fileURL options:NSDataWritingAtomic error:&error], @"%@", error);
  [self addTeardownBlock:^{
    [[NSFileManager defaultManager] removeItemAtURL:hostHomeURL error:nil];
  }];
  return hostHomeURL;
}

/// Sets (or unsets, when `value` is `nil`) a process environment variable for the duration of the
/// test, restoring its previous value afterwards.
- (void)setEnvironmentVariable:(NSString *)name value:(nullable NSString *)value {
  const char *previousValue = getenv(name.UTF8String);
  NSString *previous = previousValue ? @(previousValue) : nil;
  if (value) {
    setenv(name.UTF8String, value.UTF8String, 1);
  } else {
    unsetenv(name.UTF8String);
  }
  [self addTeardownBlock:^{
    if (previous) {
      setenv(name.UTF8String, previous.UTF8String, 1);
    } else {
      unsetenv(name.UTF8String);
    }
  }];
}

/// Expects the core debug provider's `debugTokenSource` to be read once, returning `source`.
- (void)expectDebugTokenSource:(GACAppCheckDebugTokenSource)source {
  OCMExpect([self.debugProviderMock debugTokenSource]).andReturn(source);
}

/// Returns a provider whose core debug provider resolved its debug token from `source`, which must
/// not be `GACAppCheckDebugTokenSourceLocal` (that would log the local token on the strict mock).
- (FIRAppCheckDebugProvider *)providerWithDebugTokenSource:(GACAppCheckDebugTokenSource)source
                                                 projectID:(nullable NSString *)projectID {
  [self expectDebugTokenSource:source];
  return [[FIRAppCheckDebugProvider alloc] initWithDebugProvider:self.debugProviderMock
                                                       projectID:projectID
                                                     googleAppID:kAppID];
}

@end
